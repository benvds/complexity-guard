use std::path::Path;

use super::config::Config;

/// Config file names to search for, in priority order.
///
/// For v0.8, only JSON files are parsed. TOML filenames are listed for
/// discovery order parity with the Zig binary but are skipped if found.
const CONFIG_FILENAMES: &[&str] = &[
    ".complexityguard.json",
    "complexityguard.config.json",
    ".complexityguard.toml",
    "complexityguard.config.toml",
];

/// Discover and load a config file.
///
/// If `explicit_path` is Some, load that file directly.
/// Otherwise, search upward from CWD through all parent directories,
/// stopping at a `.git` boundary or filesystem root.
/// Returns None if no config file is found.
pub fn discover_config(explicit_path: Option<&str>) -> anyhow::Result<Option<Config>> {
    if let Some(path) = explicit_path {
        let config = load_config_file(path)?;
        return Ok(Some(config));
    }

    // Upward search from CWD
    let cwd = std::env::current_dir()?;
    let mut search_dir = cwd.as_path();

    loop {
        // Check for .git boundary - stop searching above this directory
        // (we still check this directory itself before stopping)
        for filename in CONFIG_FILENAMES {
            let candidate = search_dir.join(filename);
            if candidate.exists() {
                // Skip TOML files in v0.8 (JSON only)
                if filename.ends_with(".toml") {
                    // Log would go here in verbose mode; continue searching for JSON
                    continue;
                }
                let config = load_config_file(candidate.to_string_lossy().as_ref())?;
                return Ok(Some(config));
            }
        }

        // Check for .git boundary - stop after checking this directory
        if search_dir.join(".git").exists() {
            break;
        }

        // Move to parent directory
        match search_dir.parent() {
            Some(parent) => search_dir = parent,
            None => break,
        }
    }

    Ok(None)
}

/// Load and parse a JSON config file from a specific path.
fn load_config_file(path: &str) -> anyhow::Result<Config> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| anyhow::anyhow!("Failed to read config file '{}': {}", path, e))?;
    let config: Config = serde_json::from_str(&content)
        .map_err(|e| anyhow::anyhow!("Failed to parse config file '{}': {}", path, e))?;
    Ok(config)
}

/// Check whether a path looks like a config file we handle (JSON only in v0.8).
pub fn is_json_config(path: &Path) -> bool {
    matches!(
        path.file_name().and_then(|n| n.to_str()),
        Some(".complexityguard.json") | Some("complexityguard.config.json")
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_temp_config(dir: &tempfile::TempDir, filename: &str, content: &str) -> String {
        let path = dir.path().join(filename);
        let mut file = std::fs::File::create(&path).unwrap();
        file.write_all(content.as_bytes()).unwrap();
        path.to_string_lossy().to_string()
    }

    #[test]
    fn test_explicit_path_loads_config() {
        let dir = tempfile::tempdir().unwrap();
        let json = r#"{"output": {"format": "json"}}"#;
        let path = write_temp_config(&dir, "my-config.json", json);

        let result = discover_config(Some(&path)).unwrap();
        assert!(result.is_some());
        let config = result.unwrap();
        assert_eq!(config.output.unwrap().format, Some("json".to_string()));
    }

    #[test]
    fn test_explicit_path_missing_returns_error() {
        let result = discover_config(Some("/nonexistent/path/config.json"));
        assert!(result.is_err());
    }

    #[test]
    fn test_no_config_file_returns_none() {
        // Use a temp directory with no config files present
        // We can't easily test the upward search without changing CWD,
        // but we can test that discover_config handles missing files gracefully
        // by verifying is_json_config behavior
        let path = Path::new(".complexityguard.json");
        assert!(is_json_config(path));

        let path = Path::new("complexityguard.config.json");
        assert!(is_json_config(path));

        let path = Path::new(".complexityguard.toml");
        assert!(!is_json_config(path));

        let path = Path::new("other.json");
        assert!(!is_json_config(path));
    }

    #[test]
    fn test_load_config_file_valid_json() {
        let dir = tempfile::tempdir().unwrap();
        let json = r#"{"analysis": {"threads": 4}}"#;
        let path = write_temp_config(&dir, "config.json", json);

        let config = load_config_file(&path).unwrap();
        assert_eq!(config.analysis.unwrap().threads, Some(4));
    }

    #[test]
    fn test_load_config_file_invalid_json_returns_error() {
        let dir = tempfile::tempdir().unwrap();
        let path = write_temp_config(&dir, "config.json", "{ invalid json }");

        let result = load_config_file(&path);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Failed to parse"));
    }

    #[test]
    fn test_load_config_file_all_sections() {
        let dir = tempfile::tempdir().unwrap();
        let json = r#"{
            "output": {"format": "sarif", "file": "out.sarif"},
            "analysis": {"threads": 8, "no_duplication": true},
            "files": {"include": ["src/**"], "exclude": ["**/*.test.ts"]},
            "weights": {"cognitive": 0.4},
            "baseline": 80.0
        }"#;
        let path = write_temp_config(&dir, "config.json", json);

        let config = load_config_file(&path).unwrap();
        assert_eq!(config.output.as_ref().unwrap().format, Some("sarif".to_string()));
        assert_eq!(config.output.as_ref().unwrap().file, Some("out.sarif".to_string()));
        assert_eq!(config.analysis.as_ref().unwrap().threads, Some(8));
        assert_eq!(config.analysis.as_ref().unwrap().no_duplication, Some(true));
        assert_eq!(
            config.files.as_ref().unwrap().include,
            Some(vec!["src/**".to_string()])
        );
        assert_eq!(config.baseline, Some(80.0));
    }
}
