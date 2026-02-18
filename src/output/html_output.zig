const std = @import("std");
const console = @import("console.zig");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const Allocator = std.mem.Allocator;

const ThresholdResult = cyclomatic.ThresholdResult;
const FileThresholdResults = console.FileThresholdResults;

// ── Embedded CSS ──────────────────────────────────────────────────────────────

const CSS = \\ :root {
\\   --color-ok: #4caf50;
\\   --color-warning: #f9a825;
\\   --color-error: #e53935;
\\   --bg: #f5f5f5;
\\   --text: #212121;
\\   --surface: #ffffff;
\\   --border: #e0e0e0;
\\   --muted: #757575;
\\   --radius: 6px;
\\ }
\\ @media (prefers-color-scheme: dark) {
\\   :root {
\\     --bg: #121212;
\\     --text: #e0e0e0;
\\     --surface: #1e1e1e;
\\     --border: #333333;
\\     --muted: #9e9e9e;
\\   }
\\ }
\\ *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
\\ body {
\\   font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
\\   background: var(--bg);
\\   color: var(--text);
\\   line-height: 1.5;
\\   font-size: 14px;
\\ }
\\ .container { max-width: 1200px; margin: 0 auto; padding: 1.5rem; }
\\ header { padding: 1.5rem 0 1rem; border-bottom: 1px solid var(--border); margin-bottom: 1.5rem; }
\\ header h1 { font-size: 1.4rem; font-weight: 600; }
\\ header p { color: var(--muted); font-size: 0.85rem; margin-top: 0.25rem; }
\\ .dashboard { display: grid; grid-template-columns: 280px 1fr; gap: 1.5rem; margin-bottom: 2rem; }
\\ @media (max-width: 700px) { .dashboard { grid-template-columns: 1fr; } }
\\ .score-panel {
\\   background: var(--surface);
\\   border: 1px solid var(--border);
\\   border-radius: var(--radius);
\\   padding: 1.25rem;
\\   display: flex;
\\   flex-direction: column;
\\   gap: 1rem;
\\ }
\\ .health-score {
\\   font-size: 3rem;
\\   font-weight: 700;
\\   text-align: center;
\\   line-height: 1.1;
\\ }
\\ .grade { font-size: 2rem; color: var(--muted); margin-left: 0.25rem; }
\\ .score-ok { color: var(--color-ok); }
\\ .score-warning { color: var(--color-warning); }
\\ .score-error { color: var(--color-error); }
\\ .dist-bar {
\\   display: flex;
\\   height: 8px;
\\   border-radius: 4px;
\\   overflow: hidden;
\\   background: var(--border);
\\ }
\\ .dist-ok { background: var(--color-ok); }
\\ .dist-warning { background: var(--color-warning); }
\\ .dist-error { background: var(--color-error); }
\\ .dist-label { font-size: 0.75rem; color: var(--muted); display: flex; justify-content: space-between; margin-top: 0.25rem; }
\\ .summary-stats { font-size: 0.8rem; color: var(--muted); text-align: center; }
\\ .summary-stats strong { color: var(--text); }
\\ .hotspots-panel { display: flex; flex-direction: column; gap: 0.75rem; }
\\ .hotspots-panel h2 { font-size: 1rem; font-weight: 600; margin-bottom: 0.25rem; }
\\ .hotspot-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 0.75rem; }
\\ .hotspot-card {
\\   background: var(--surface);
\\   border: 1px solid var(--border);
\\   border-left-width: 3px;
\\   border-radius: var(--radius);
\\   padding: 0.75rem 1rem;
\\ }
\\ .hotspot-card.ok { border-left-color: var(--color-ok); }
\\ .hotspot-card.warning { border-left-color: var(--color-warning); }
\\ .hotspot-card.error { border-left-color: var(--color-error); }
\\ .hotspot-card h3 { font-size: 0.9rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
\\ .hotspot-file { font-size: 0.75rem; color: var(--muted); margin: 0.1rem 0 0.5rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
\\ .hotspot-metrics { font-size: 0.75rem; color: var(--text); }
\\ .hotspot-violations { font-size: 0.7rem; margin-top: 0.35rem; display: flex; flex-wrap: wrap; gap: 0.25rem; }
\\ .violation-tag {
\\   background: color-mix(in srgb, var(--color-error) 12%, transparent);
\\   color: var(--color-error);
\\   border: 1px solid color-mix(in srgb, var(--color-error) 25%, transparent);
\\   border-radius: 3px;
\\   padding: 0.1rem 0.4rem;
\\ }
\\ .violation-tag.warning {
\\   background: color-mix(in srgb, var(--color-warning) 12%, transparent);
\\   color: var(--color-warning);
\\   border-color: color-mix(in srgb, var(--color-warning) 25%, transparent);
\\ }
\\ .empty-hotspots { color: var(--muted); font-size: 0.875rem; padding: 1rem; text-align: center; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); }
\\ footer { border-top: 1px solid var(--border); padding: 1rem 0; margin-top: 2rem; text-align: center; color: var(--muted); font-size: 0.75rem; }
;

// ── Embedded JS ───────────────────────────────────────────────────────────────

const JS =
    \\(function() {
    \\  // Placeholder for future interactive features (Plan 02: sort/expand)
    \\})();
;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Map score to letter grade: >=90=A, >=80=B, >=65=C, >=50=D, else=F
fn scoreToGrade(score: f64) []const u8 {
    if (score >= 90.0) return "A";
    if (score >= 80.0) return "B";
    if (score >= 65.0) return "C";
    if (score >= 50.0) return "D";
    return "F";
}

/// Map score to CSS color class: ok (>=80), warning (>=50), error (<50)
fn scoreToColorClass(score: f64) []const u8 {
    if (score >= 80.0) return "ok";
    if (score >= 50.0) return "warning";
    return "error";
}

/// Average health_score across results; returns 100.0 for empty slice
fn computeFileHealthScore(results: []const ThresholdResult) f64 {
    if (results.len == 0) return 100.0;
    var sum: f64 = 0.0;
    for (results) |r| {
        sum += r.health_score;
    }
    return sum / @as(f64, @floatFromInt(results.len));
}

/// Write HTML-escaped version of s to w
fn writeHtmlEscaped(w: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '<' => try w.writeAll("&lt;"),
            '>' => try w.writeAll("&gt;"),
            '&' => try w.writeAll("&amp;"),
            '"' => try w.writeAll("&quot;"),
            else => try w.writeByte(c),
        }
    }
}

/// Write the <head> element with inline CSS
fn writeHead(w: anytype, tool_version: []const u8) !void {
    try w.writeAll("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n");
    try w.writeAll("  <meta charset=\"UTF-8\">\n");
    try w.writeAll("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
    try w.print("  <meta name=\"generator\" content=\"ComplexityGuard {s}\">\n", .{tool_version});
    try w.writeAll("  <title>ComplexityGuard Report</title>\n");
    try w.writeAll("  <style>\n");
    try w.writeAll(CSS);
    try w.writeAll("  </style>\n");
    try w.writeAll("</head>\n");
}

/// Write the distribution bar section showing healthy/warning/error file counts
fn writeDistributionBar(w: anytype, file_results: []const FileThresholdResults) !void {
    var ok_count: u32 = 0;
    var warn_count: u32 = 0;
    var err_count: u32 = 0;

    for (file_results) |fr| {
        const score = computeFileHealthScore(fr.results);
        if (score >= 80.0) {
            ok_count += 1;
        } else if (score >= 50.0) {
            warn_count += 1;
        } else {
            err_count += 1;
        }
    }

    const total = ok_count + warn_count + err_count;

    try w.writeAll("      <div class=\"dist-bar\">\n");
    if (total > 0) {
        const ok_pct = @as(f64, @floatFromInt(ok_count)) / @as(f64, @floatFromInt(total)) * 100.0;
        const warn_pct = @as(f64, @floatFromInt(warn_count)) / @as(f64, @floatFromInt(total)) * 100.0;
        const err_pct = @as(f64, @floatFromInt(err_count)) / @as(f64, @floatFromInt(total)) * 100.0;
        if (ok_pct > 0) try w.print("        <div class=\"dist-ok\" style=\"width:{d:.1}%\"></div>\n", .{ok_pct});
        if (warn_pct > 0) try w.print("        <div class=\"dist-warning\" style=\"width:{d:.1}%\"></div>\n", .{warn_pct});
        if (err_pct > 0) try w.print("        <div class=\"dist-error\" style=\"width:{d:.1}%\"></div>\n", .{err_pct});
    }
    try w.writeAll("      </div>\n");
    try w.print("      <div class=\"dist-label\"><span>{d} healthy</span><span>{d} warning</span><span>{d} error</span></div>\n", .{
        ok_count, warn_count, err_count,
    });
}

/// Hotspot item used for sorting
const HotspotItem = struct {
    result: ThresholdResult,
    file_path: []const u8,
};

/// Write up to 5 hotspot function cards (worst health score first)
fn writeHotspots(w: anytype, file_results: []const FileThresholdResults, allocator: Allocator) !void {
    try w.writeAll("    <div class=\"hotspots-panel\">\n");
    try w.writeAll("      <h2>Top Hotspots</h2>\n");

    // Collect all functions
    var items = std.ArrayList(HotspotItem).empty;
    defer items.deinit(allocator);

    for (file_results) |fr| {
        for (fr.results) |r| {
            try items.append(allocator, .{ .result = r, .file_path = fr.path });
        }
    }

    if (items.items.len == 0) {
        try w.writeAll("      <div class=\"empty-hotspots\">No functions found.</div>\n");
        try w.writeAll("    </div>\n");
        return;
    }

    // Bubble sort ascending by health_score (lowest = worst = first)
    const arr = items.items;
    var i: usize = 0;
    while (i < arr.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < arr.len) : (j += 1) {
            if (arr[j].result.health_score < arr[i].result.health_score) {
                const tmp = arr[i];
                arr[i] = arr[j];
                arr[j] = tmp;
            }
        }
    }

    const top = @min(5, arr.len);

    try w.writeAll("      <div class=\"hotspot-cards\">\n");
    var idx: usize = 0;
    while (idx < top) : (idx += 1) {
        const item = arr[idx];
        const r = item.result;
        const color_class = scoreToColorClass(r.health_score);

        try w.print("        <div class=\"hotspot-card {s}\">\n", .{color_class});
        try w.writeAll("          <h3>");
        try writeHtmlEscaped(w, r.function_name);
        try w.writeAll("</h3>\n");
        try w.writeAll("          <p class=\"hotspot-file\">");
        try writeHtmlEscaped(w, item.file_path);
        try w.print(":{d}</p>\n", .{r.start_line});
        try w.writeAll("          <div class=\"hotspot-metrics\">");
        try w.print("Cyclomatic: {d} | Cognitive: {d} | Halstead Vol: {d:.0}", .{
            r.complexity,
            r.cognitive_complexity,
            r.halstead_volume,
        });
        if (r.function_length > 0) {
            try w.print(" | Lines: {d}", .{r.function_length});
        }
        try w.writeAll("</div>\n");

        // Violations
        try w.writeAll("          <div class=\"hotspot-violations\">\n");
        if (r.status != .ok) {
            const cls = if (r.status == .@"error") "" else " warning";
            try w.print("            <span class=\"violation-tag{s}\">cyclomatic {d}</span>\n", .{ cls, r.complexity });
        }
        if (r.cognitive_status != .ok) {
            const cls = if (r.cognitive_status == .@"error") "" else " warning";
            try w.print("            <span class=\"violation-tag{s}\">cognitive {d}</span>\n", .{ cls, r.cognitive_complexity });
        }
        if (r.halstead_volume_status != .ok) {
            const cls = if (r.halstead_volume_status == .@"error") "" else " warning";
            try w.print("            <span class=\"violation-tag{s}\">halstead vol {d:.0}</span>\n", .{ cls, r.halstead_volume });
        }
        if (r.function_length_status != .ok) {
            const cls = if (r.function_length_status == .@"error") "" else " warning";
            try w.print("            <span class=\"violation-tag{s}\">length {d}</span>\n", .{ cls, r.function_length });
        }
        if (r.params_count_status != .ok) {
            const cls = if (r.params_count_status == .@"error") "" else " warning";
            try w.print("            <span class=\"violation-tag{s}\">params {d}</span>\n", .{ cls, r.params_count });
        }
        if (r.nesting_depth_status != .ok) {
            const cls = if (r.nesting_depth_status == .@"error") "" else " warning";
            try w.print("            <span class=\"violation-tag{s}\">depth {d}</span>\n", .{ cls, r.nesting_depth });
        }
        try w.writeAll("          </div>\n");
        try w.writeAll("        </div>\n");
    }
    try w.writeAll("      </div>\n");
    try w.writeAll("    </div>\n");
}

/// Write the dashboard section (score panel + hotspots)
fn writeDashboard(
    w: anytype,
    file_results: []const FileThresholdResults,
    project_score: f64,
    warning_count: u32,
    error_count: u32,
    allocator: Allocator,
) !void {
    const grade = scoreToGrade(project_score);
    const color_class = scoreToColorClass(project_score);

    // Count total functions
    var total_functions: u32 = 0;
    for (file_results) |fr| {
        total_functions += @intCast(fr.results.len);
    }

    try w.writeAll("  <main>\n");
    try w.writeAll("    <section class=\"dashboard\">\n");

    // Score panel
    try w.writeAll("      <div class=\"score-panel\">\n");
    try w.print("        <div class=\"health-score score-{s}\">{d:.0}<span class=\"grade\">{s}</span></div>\n", .{
        color_class,
        project_score,
        grade,
    });
    try writeDistributionBar(w, file_results);
    try w.print("        <div class=\"summary-stats\">Files: <strong>{d}</strong> | Functions: <strong>{d}</strong> | Errors: <strong>{d}</strong> | Warnings: <strong>{d}</strong></div>\n", .{
        file_results.len,
        total_functions,
        error_count,
        warning_count,
    });
    try w.writeAll("      </div>\n");

    // Hotspots
    try writeHotspots(w, file_results, allocator);

    try w.writeAll("    </section>\n");
    try w.writeAll("  </main>\n");
}

/// Write the footer with tool version and generation timestamp
fn writeFooter(w: anytype, tool_version: []const u8) !void {
    const ts = std.time.timestamp();
    try w.writeAll("  <footer>\n    <div class=\"container\">\n");
    try w.print("      Generated by ComplexityGuard {s} &mdash; <time>{d}</time>\n", .{ tool_version, ts });
    try w.writeAll("    </div>\n  </footer>\n");
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Build a self-contained HTML report. Returns heap-allocated HTML string; caller owns the slice.
pub fn buildHtmlReport(
    allocator: Allocator,
    file_results: []const FileThresholdResults,
    warning_count: u32,
    error_count: u32,
    project_score: f64,
    tool_version: []const u8,
) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try writeHead(w, tool_version);
    try w.writeAll("<body>\n");
    try w.writeAll("  <header>\n    <div class=\"container\">\n");
    try w.writeAll("      <h1>ComplexityGuard Report</h1>\n");
    try w.print("      <p>Version {s}</p>\n", .{tool_version});
    try w.writeAll("    </div>\n  </header>\n");
    try w.writeAll("  <div class=\"container\">\n");
    try writeDashboard(w, file_results, project_score, warning_count, error_count, allocator);
    try w.writeAll("  </div>\n");
    try writeFooter(w, tool_version);
    try w.writeAll("  <script>\n");
    try w.writeAll(JS);
    try w.writeAll("  </script>\n");
    try w.writeAll("</body>\n</html>\n");

    return try allocator.dupe(u8, buf.items);
}

// ── TESTS ─────────────────────────────────────────────────────────────────────

test "scoreToGrade" {
    try std.testing.expectEqualStrings("A", scoreToGrade(90.0));
    try std.testing.expectEqualStrings("A", scoreToGrade(95.0));
    try std.testing.expectEqualStrings("B", scoreToGrade(80.0));
    try std.testing.expectEqualStrings("B", scoreToGrade(89.9));
    try std.testing.expectEqualStrings("C", scoreToGrade(65.0));
    try std.testing.expectEqualStrings("C", scoreToGrade(79.9));
    try std.testing.expectEqualStrings("D", scoreToGrade(50.0));
    try std.testing.expectEqualStrings("D", scoreToGrade(64.9));
    try std.testing.expectEqualStrings("F", scoreToGrade(49.0));
    try std.testing.expectEqualStrings("F", scoreToGrade(0.0));
}

test "scoreToColorClass" {
    try std.testing.expectEqualStrings("ok", scoreToColorClass(80.0));
    try std.testing.expectEqualStrings("ok", scoreToColorClass(100.0));
    try std.testing.expectEqualStrings("warning", scoreToColorClass(50.0));
    try std.testing.expectEqualStrings("warning", scoreToColorClass(79.9));
    try std.testing.expectEqualStrings("error", scoreToColorClass(49.9));
    try std.testing.expectEqualStrings("error", scoreToColorClass(0.0));
}

test "computeFileHealthScore" {
    // Empty results → 100.0
    const empty = [_]ThresholdResult{};
    try std.testing.expectEqual(@as(f64, 100.0), computeFileHealthScore(&empty));

    // Known values → correct average
    const results = [_]ThresholdResult{
        .{
            .complexity = 5,
            .status = .ok,
            .function_name = "a",
            .function_kind = "function",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 0,
            .cognitive_status = .ok,
            .health_score = 80.0,
        },
        .{
            .complexity = 3,
            .status = .ok,
            .function_name = "b",
            .function_kind = "function",
            .start_line = 10,
            .start_col = 0,
            .cognitive_complexity = 0,
            .cognitive_status = .ok,
            .health_score = 60.0,
        },
    };
    try std.testing.expectEqual(@as(f64, 70.0), computeFileHealthScore(&results));
}

test "writeHtmlEscaped" {
    const allocator = std.testing.allocator;
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try writeHtmlEscaped(w, "<script>alert(\"&foo>\")</script>");
    try std.testing.expectEqualStrings(
        "&lt;script&gt;alert(&quot;&amp;foo&gt;&quot;)&lt;/script&gt;",
        buf.items,
    );
}

test "buildHtmlReport basic" {
    const allocator = std.testing.allocator;

    const results = [_]ThresholdResult{
        .{
            .complexity = 12,
            .status = .warning,
            .function_name = "processData",
            .function_kind = "function",
            .start_line = 5,
            .start_col = 0,
            .cognitive_complexity = 8,
            .cognitive_status = .ok,
            .health_score = 72.0,
        },
    };
    const file_results = [_]FileThresholdResults{
        .{ .path = "src/app.ts", .results = &results },
    };

    const html = try buildHtmlReport(
        allocator,
        &file_results,
        1,
        0,
        72.0,
        "0.5.0",
    );
    defer allocator.free(html);

    // Must start with DOCTYPE
    try std.testing.expect(std.mem.startsWith(u8, html, "<!DOCTYPE html>"));

    // Must contain key sections
    try std.testing.expect(std.mem.indexOf(u8, html, "<html") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "ComplexityGuard") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "processData") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "src/app.ts") != null);

    // Must not have any external references
    try std.testing.expect(std.mem.indexOf(u8, html, "<link") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<script src") == null);

    // Must contain inline CSS and JS
    try std.testing.expect(std.mem.indexOf(u8, html, "<style>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<script>") != null);

    // Must contain prefers-color-scheme
    try std.testing.expect(std.mem.indexOf(u8, html, "prefers-color-scheme") != null);
}
