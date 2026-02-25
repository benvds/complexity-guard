use rustc_hash::FxHashMap;

use crate::metrics::halstead::is_type_only_node;
use crate::types::{CloneGroup, CloneInstance, DuplicationConfig, DuplicationResult, Token};

/// Rolling hash base constant matching Zig implementation.
const HASH_BASE: u64 = 37;

/// Maximum bucket size for hash buckets. Buckets larger than this are likely
/// common patterns (boilerplate, short keywords) and are discarded to prevent
/// O(N^2) verification.
const MAX_BUCKET_SIZE: usize = 1000;

/// Tokenize a tree-sitter AST into a normalized token sequence.
///
/// Strips comments, whitespace, structural punctuation, and TypeScript type annotations.
/// Normalizes identifier nodes to sentinel "V" for Type 2 clone detection.
/// Each token stores a precomputed hash for efficient rolling hash computation.
pub fn tokenize_tree(root: tree_sitter::Node, source: &[u8]) -> Vec<Token> {
    let mut tokens = Vec::new();
    tokenize_node(root, source, &mut tokens);
    tokens
}

/// Recursively collect normalized tokens from an AST node.
#[allow(clippy::only_used_in_recursion)]
fn tokenize_node(node: tree_sitter::Node, source: &[u8], tokens: &mut Vec<Token>) {
    let kind = node.kind();

    // Skip entire TypeScript type annotation subtrees
    if is_type_only_node(kind) {
        return;
    }

    if node.child_count() == 0 {
        // Leaf node
        if is_skipped_kind(kind) {
            return;
        }

        let normalized = normalize_kind(kind);
        tokens.push(Token {
            kind: normalized,
            kind_hash: token_hash(normalized),
            start_byte: node.start_byte(),
            end_byte: node.end_byte(),
        });
        return;
    }

    // Non-leaf: recurse into all children
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            tokenize_node(child, source, tokens);
        }
    }
}

/// Returns true for token kinds that should be skipped during tokenization.
fn is_skipped_kind(kind: &str) -> bool {
    matches!(
        kind,
        "comment" | "line_comment" | "block_comment" | ";" | "," | "hash_bang_line"
    )
}

/// Returns the normalized kind for a token.
/// Identifiers (all variants) are normalized to sentinel "V" for Type 2 clone detection.
/// Returns `&'static str` since all inputs come from tree-sitter (static grammar strings).
fn normalize_kind(kind: &'static str) -> &'static str {
    match kind {
        "identifier"
        | "property_identifier"
        | "shorthand_property_identifier"
        | "shorthand_property_identifier_pattern" => "V",
        other => other,
    }
}

/// Compute a hash value for a token kind string using Rabin-Karp polynomial hashing.
fn token_hash(kind: &str) -> u64 {
    let mut h: u64 = 0;
    for &c in kind.as_bytes() {
        h = h.wrapping_mul(HASH_BASE).wrapping_add(c as u64);
    }
    h
}

/// Rolling hash state for a sliding window over a token sequence.
struct RollingHasher {
    hash: u64,
    /// B^(window_size - 1) for removing the leftmost token.
    base_pow: u64,
}

impl RollingHasher {
    /// Initialize the hasher over the first `window` tokens.
    fn new(tokens: &[Token], window: usize) -> Self {
        let mut h: u64 = 0;
        let mut bpow: u64 = 1;
        for (i, token) in tokens.iter().enumerate().take(window) {
            h = h.wrapping_mul(HASH_BASE).wrapping_add(token.kind_hash);
            if i < window - 1 {
                bpow = bpow.wrapping_mul(HASH_BASE);
            }
        }
        RollingHasher {
            hash: h,
            base_pow: bpow,
        }
    }

    /// Slide the window: remove left token, add right token.
    fn roll(&mut self, remove: &Token, add: &Token) {
        self.hash = self
            .hash
            .wrapping_sub(remove.kind_hash.wrapping_mul(self.base_pow))
            .wrapping_mul(HASH_BASE)
            .wrapping_add(add.kind_hash);
    }
}

/// Detect code clones across multiple files using Rabin-Karp rolling hash.
pub fn detect_duplication(
    file_tokens: &[&[Token]],
    config: &DuplicationConfig,
) -> DuplicationResult {
    let window = config.min_tokens as usize;

    if file_tokens.is_empty() || window == 0 {
        return DuplicationResult {
            clone_groups: Vec::new(),
            total_tokens: 0,
            cloned_tokens: 0,
            duplication_percentage: 0.0,
        };
    }

    // Build hash index: hash -> Vec<(file_index, start_token_position)>
    let mut index: FxHashMap<u64, Vec<(usize, usize)>> = FxHashMap::default();

    for (file_idx, tokens) in file_tokens.iter().enumerate() {
        if tokens.len() < window {
            continue;
        }

        let mut hasher = RollingHasher::new(tokens, window);
        let mut start = 0;

        while start + window <= tokens.len() {
            let bucket = index.entry(hasher.hash).or_default();
            bucket.push((file_idx, start));

            if start + window < tokens.len() {
                hasher.roll(&tokens[start], &tokens[start + window]);
            }
            start += 1;
        }
    }

    // Form clone groups from verified hash collisions
    let mut clone_groups: Vec<CloneGroup> = Vec::new();

    // Per-file interval lists for counting cloned tokens
    let num_files = file_tokens.len();
    let mut intervals_per_file: Vec<Vec<(usize, usize)>> = vec![Vec::new(); num_files];

    for bucket in index.values() {
        if bucket.len() < 2 || bucket.len() > MAX_BUCKET_SIZE {
            continue;
        }

        let mut instances: Vec<CloneInstance> = Vec::new();
        let mut added: Vec<bool> = vec![false; bucket.len()];

        for i in 0..bucket.len() {
            for j in (i + 1)..bucket.len() {
                let (fi_a, st_a) = bucket[i];
                let (fi_b, st_b) = bucket[j];

                // Skip identical position in same file
                if fi_a == fi_b && st_a == st_b {
                    continue;
                }

                // Verify token-by-token match
                if tokens_match(file_tokens[fi_a], st_a, file_tokens[fi_b], st_b, window) {
                    if !added[i] {
                        added[i] = true;
                        instances.push(make_instance(fi_a, st_a, window, file_tokens[fi_a]));
                        intervals_per_file[fi_a].push((st_a, st_a + window));
                    }
                    if !added[j] {
                        added[j] = true;
                        instances.push(make_instance(fi_b, st_b, window, file_tokens[fi_b]));
                        intervals_per_file[fi_b].push((st_b, st_b + window));
                    }
                }
            }
        }

        if instances.len() >= 2 {
            clone_groups.push(CloneGroup {
                instances,
                token_count: window as u32,
            });
        }
    }

    // Count total tokens and cloned tokens (with interval merging)
    let mut total_tokens: usize = 0;
    let mut cloned_tokens: usize = 0;

    for (file_idx, tokens) in file_tokens.iter().enumerate() {
        total_tokens += tokens.len();
        cloned_tokens += count_merged_intervals(&mut intervals_per_file[file_idx]);
    }

    let duplication_percentage = if total_tokens == 0 {
        0.0
    } else {
        cloned_tokens as f64 / total_tokens as f64 * 100.0
    };

    DuplicationResult {
        clone_groups,
        total_tokens,
        cloned_tokens,
        duplication_percentage,
    }
}

/// Create a CloneInstance from file tokens.
fn make_instance(
    file_index: usize,
    start_token: usize,
    window: usize,
    _tokens: &[Token],
) -> CloneInstance {
    CloneInstance {
        file_index,
        start_token,
        end_token: start_token + window,
        start_line: 0,
        end_line: 0,
    }
}

/// Verify that two token windows have identical normalized token sequences.
/// Uses pointer comparison on static strings for speed, with string fallback.
fn tokens_match(
    a_tokens: &[Token],
    a_start: usize,
    b_tokens: &[Token],
    b_start: usize,
    window: usize,
) -> bool {
    for i in 0..window {
        let a = a_tokens[a_start + i].kind;
        let b = b_tokens[b_start + i].kind;
        // Fast path: pointer equality for static strings from same grammar
        if !std::ptr::eq(a.as_ptr(), b.as_ptr()) && a != b {
            return false;
        }
    }
    true
}

/// Merge overlapping intervals and return total non-overlapping token count.
fn count_merged_intervals(intervals: &mut [(usize, usize)]) -> usize {
    if intervals.is_empty() {
        return 0;
    }

    intervals.sort_by_key(|&(start, _)| start);

    let mut total: usize = 0;
    let mut cur_start = intervals[0].0;
    let mut cur_end = intervals[0].1;

    for &(start, end) in intervals.iter().skip(1) {
        if start <= cur_end {
            // Overlapping or adjacent
            if end > cur_end {
                cur_end = end;
            }
        } else {
            // Gap
            total += cur_end - cur_start;
            cur_start = start;
            cur_end = end;
        }
    }
    total += cur_end - cur_start;

    total
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    fn parse_to_tokens(source: &str) -> Vec<Token> {
        let language: tree_sitter::Language = tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        tokenize_tree(tree.root_node(), source.as_bytes())
    }

    #[test]
    fn tokenize_produces_tokens() {
        let source = "function add(a: number, b: number): number { return a + b; }";
        let tokens = parse_to_tokens(source);
        assert!(
            !tokens.is_empty(),
            "should produce tokens from a real function"
        );
    }

    #[test]
    fn tokenize_skips_comments() {
        let source = r#"
// This is a comment
function greet(name: string): string {
  /* block comment */
  return name;
}
"#;
        let tokens = parse_to_tokens(source);
        for tok in &tokens {
            assert_ne!(tok.kind, "comment");
            assert_ne!(tok.kind, "line_comment");
            assert_ne!(tok.kind, "block_comment");
        }
        assert!(!tokens.is_empty());
    }

    #[test]
    fn tokenize_normalizes_identifiers_to_v() {
        let source = "function myFunc(myParam: string): void { const myVar = myParam; }";
        let tokens = parse_to_tokens(source);
        // No raw "identifier" kind should remain
        for tok in &tokens {
            assert_ne!(
                tok.kind, "identifier",
                "identifier should be normalized to V"
            );
        }
        // At least one "V" token
        assert!(tokens.iter().any(|t| t.kind == "V"), "should have V tokens");
    }

    #[test]
    fn tokenize_skips_type_annotations() {
        // TS with types
        let ts_source = "function f(x: number, y: string): boolean { return x > 0; }";
        // JS without types
        let js_source = "function f(x, y) { return x > 0; }";

        let ts_tokens = parse_to_tokens(ts_source);
        let js_tokens = parse_to_tokens(js_source);

        assert_eq!(
            ts_tokens.len(),
            js_tokens.len(),
            "TS and JS should produce same token count after type stripping"
        );
    }

    #[test]
    fn token_hash_deterministic() {
        let h1 = token_hash("function");
        let h2 = token_hash("function");
        assert_eq!(h1, h2, "same input should produce same hash");

        let h3 = token_hash("return");
        assert_ne!(h1, h3, "different inputs should produce different hashes");
    }

    #[test]
    fn is_skipped_kind_filters_correctly() {
        assert!(is_skipped_kind("comment"));
        assert!(is_skipped_kind("line_comment"));
        assert!(is_skipped_kind("block_comment"));
        assert!(is_skipped_kind(";"));
        assert!(is_skipped_kind(","));
        assert!(is_skipped_kind("hash_bang_line"));
        assert!(!is_skipped_kind("identifier"));
        assert!(!is_skipped_kind("function"));
    }

    #[test]
    fn detect_duplication_finds_clones_in_identical_functions() {
        let source_a = r#"function processUserData(input: string): string {
  const result = input.trim().toLowerCase();
  if (result.length === 0) {
    return "empty";
  }
  return result.split(",").join(";");
}"#;
        let source_b = r#"function processItemData(input: string): string {
  const result = input.trim().toLowerCase();
  if (result.length === 0) {
    return "empty";
  }
  return result.split(",").join(";");
}"#;

        let tokens_a = parse_to_tokens(source_a);
        let tokens_b = parse_to_tokens(source_b);

        let config = DuplicationConfig {
            min_tokens: 10,
            enabled: true,
        };
        let result = detect_duplication(&[tokens_a.as_slice(), tokens_b.as_slice()], &config);
        assert!(
            !result.clone_groups.is_empty(),
            "should detect clones between identical functions"
        );
    }

    #[test]
    fn detect_duplication_type2_different_identifiers() {
        let source_email = r#"function validateEmail(email: string): boolean {
  const trimmed = email.trim();
  if (trimmed.length === 0) {
    return false;
  }
  return trimmed.includes("@");
}"#;
        let source_phone = r#"function validatePhone(phone: string): boolean {
  const cleaned = phone.trim();
  if (cleaned.length === 0) {
    return false;
  }
  return cleaned.includes("+");
}"#;

        let tokens_e = parse_to_tokens(source_email);
        let tokens_p = parse_to_tokens(source_phone);

        let config = DuplicationConfig {
            min_tokens: 8,
            enabled: true,
        };
        let result = detect_duplication(&[tokens_e.as_slice(), tokens_p.as_slice()], &config);
        assert!(
            !result.clone_groups.is_empty(),
            "should detect Type 2 clones with different identifiers"
        );
    }

    #[test]
    fn detect_duplication_interval_merging() {
        let source = r#"function processUserData(input: string): string {
  const result = input.trim().toLowerCase();
  if (result.length === 0) {
    return "empty";
  }
  return result.split(",").join(";");
}
function processItemData(input: string): string {
  const result = input.trim().toLowerCase();
  if (result.length === 0) {
    return "empty";
  }
  return result.split(",").join(";");
}"#;

        let tokens = parse_to_tokens(source);

        let config = DuplicationConfig {
            min_tokens: 8,
            enabled: true,
        };
        let result = detect_duplication(&[tokens.as_slice()], &config);
        assert!(
            result.duplication_percentage <= 100.0,
            "duplication_pct must not exceed 100%, got {}",
            result.duplication_percentage
        );
    }

    #[test]
    fn tokenize_duplication_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/duplication_cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let tokens = parse_to_tokens(&source);

        assert!(!tokens.is_empty(), "fixture should produce tokens");
        // All identifiers should be normalized to "V"
        for tok in &tokens {
            assert_ne!(tok.kind, "identifier", "identifiers should be normalized");
            assert_ne!(
                tok.kind, "property_identifier",
                "property_identifiers should be normalized"
            );
        }
        // Should have at least some "V" tokens
        assert!(tokens.iter().any(|t| t.kind == "V"), "should have V tokens");
    }

    #[test]
    fn count_merged_intervals_basic() {
        let mut intervals = vec![(0, 5), (3, 8), (10, 15)];
        let count = count_merged_intervals(&mut intervals);
        // (0,5)+(3,8) merge to (0,8)=8, plus (10,15)=5, total=13
        assert_eq!(count, 13);
    }

    #[test]
    fn count_merged_intervals_no_overlap() {
        let mut intervals = vec![(0, 3), (5, 8), (10, 12)];
        let count = count_merged_intervals(&mut intervals);
        assert_eq!(count, 3 + 3 + 2);
    }

    #[test]
    fn count_merged_intervals_empty() {
        let mut intervals: Vec<(usize, usize)> = vec![];
        let count = count_merged_intervals(&mut intervals);
        assert_eq!(count, 0);
    }
}
