const std = @import("std");
const console = @import("console.zig");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const Allocator = std.mem.Allocator;

const ThresholdResult = cyclomatic.ThresholdResult;
const ThresholdStatus = cyclomatic.ThresholdStatus;
const FileThresholdResults = console.FileThresholdResults;

// ── Embedded CSS ──────────────────────────────────────────────────────────────

const CSS =
    \\ :root {
    \\   --color-ok: #4caf50;
    \\   --color-warning: #f9a825;
    \\   --color-error: #e53935;
    \\   --color-ok-bg: #4caf50;
    \\   --color-warning-bg: #f9a825;
    \\   --color-error-bg: #e53935;
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
    \\
    \\ /* File table */
    \\ .file-table-section { margin-bottom: 2rem; }
    \\ .file-table-section h2 { font-size: 1rem; font-weight: 600; margin-bottom: 0.75rem; }
    \\ .file-table { width: 100%; border-collapse: collapse; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; }
    \\ .file-table th {
    \\   text-align: left;
    \\   padding: 0.6rem 0.75rem;
    \\   font-size: 0.8rem;
    \\   font-weight: 600;
    \\   color: var(--muted);
    \\   border-bottom: 1px solid var(--border);
    \\   background: var(--bg);
    \\   cursor: pointer;
    \\   user-select: none;
    \\   white-space: nowrap;
    \\ }
    \\ .file-table th:hover { color: var(--text); }
    \\ .file-table th::after { content: ''; margin-left: 0.3em; }
    \\ .file-table th.sort-asc::after { content: '↑'; }
    \\ .file-table th.sort-desc::after { content: '↓'; }
    \\ .file-table td { padding: 0.5rem 0.75rem; font-size: 0.85rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
    \\ .file-table tr:last-child td { border-bottom: none; }
    \\ .file-row { cursor: pointer; }
    \\ .file-row:hover td { background: color-mix(in srgb, var(--border) 30%, transparent); }
    \\ .file-row td:first-child { font-family: monospace; font-size: 0.8rem; direction: rtl; }
    \\ .truncate { display: block; text-overflow: ellipsis; white-space: nowrap; overflow: hidden; unicode-bidi: plaintext; }
    \\ .detail-row { display: none; }
    \\ .detail-row.expanded { display: table-row; }
    \\ .detail-row td { padding: 0; background: color-mix(in srgb, var(--border) 15%, transparent); }
    \\ .detail-inner { padding: 0.75rem; }
    \\
    \\ /* Nested function table */
    \\ .fn-table { width: 100%; border-collapse: collapse; font-size: 0.78rem; }
    \\ .fn-table th { text-align: left; padding: 0.35rem 0.5rem; font-weight: 600; color: var(--muted); border-bottom: 1px solid var(--border); white-space: nowrap; }
    \\ .fn-table td { padding: 0.3rem 0.5rem; border-bottom: 1px solid color-mix(in srgb, var(--border) 50%, transparent); white-space: nowrap; }
    \\ .fn-table tr:last-child td { border-bottom: none; }
    \\ .fn-table td:first-child { font-family: monospace; max-width: 220px; overflow: hidden; text-overflow: ellipsis; }
    \\
    \\ /* Metric bars */
    \\ .metric-bar { display: inline-block; width: 60px; height: 6px; background: var(--border); border-radius: 3px; overflow: hidden; vertical-align: middle; margin-left: 0.25rem; }
    \\ .metric-bar__fill { height: 100%; border-radius: 3px; }
    \\ .metric-bar__fill.ok { background: var(--color-ok); }
    \\ .metric-bar__fill.warning { background: var(--color-warning); }
    \\ .metric-bar__fill.error { background: var(--color-error); }
    \\
    \\ /* Score badges in file table */
    \\ .score-badge { display: inline-block; min-width: 2.5em; text-align: center; font-weight: 600; padding: 0.1em 0.4em; border-radius: 3px; font-size: 0.82rem; }
    \\ .score-badge.ok { background: color-mix(in srgb, var(--color-ok) 15%, transparent); color: var(--color-ok); }
    \\ .score-badge.warning { background: color-mix(in srgb, var(--color-warning) 15%, transparent); color: var(--color-warning); }
    \\ .score-badge.error { background: color-mix(in srgb, var(--color-error) 15%, transparent); color: var(--color-error); }
    \\
    \\ /* Visualizations */
    \\ .visualizations { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-bottom: 2rem; }
    \\ @media (max-width: 800px) { .visualizations { grid-template-columns: 1fr; } }
    \\ .viz-panel { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 1rem; }
    \\ .viz-panel h2 { font-size: 0.95rem; font-weight: 600; margin-bottom: 0.75rem; }
    \\ .treemap { width: 100%; display: block; }
    \\ .treemap rect { stroke: var(--bg); stroke-width: 2; transition: opacity 0.15s; }
    \\ .treemap rect:hover { opacity: 0.8; }
    \\ .treemap text { fill: var(--surface); font-size: 10px; pointer-events: none; }
    \\ .bar-chart { width: 100%; display: block; }
    \\
    \\ footer { border-top: 1px solid var(--border); padding: 1rem 0; margin-top: 2rem; text-align: center; color: var(--muted); font-size: 0.75rem; }
;

// ── Embedded JS ───────────────────────────────────────────────────────────────

const JS =
    \\(function() {
    \\  // Sort a table by column index. type: 'str' or 'num'
    \\  window.sortTable = function(tableId, colIndex, type) {
    \\    var table = document.getElementById(tableId);
    \\    if (!table) return;
    \\    var tbody = table.querySelector('tbody');
    \\    if (!tbody) return;
    \\    var rows = Array.from(tbody.querySelectorAll('tr.file-row'));
    \\    var prevCol = parseInt(table.dataset.sortCol, 10);
    \\    var prevDir = table.dataset.sortDir || 'asc';
    \\    var dir = (prevCol === colIndex && prevDir === 'asc') ? 'desc' : 'asc';
    \\    table.dataset.sortCol = colIndex;
    \\    table.dataset.sortDir = dir;
    \\    rows.sort(function(a, b) {
    \\      var aCells = a.querySelectorAll('td');
    \\      var bCells = b.querySelectorAll('td');
    \\      var aVal = aCells[colIndex] ? (aCells[colIndex].dataset.value || '') : '';
    \\      var bVal = bCells[colIndex] ? (bCells[colIndex].dataset.value || '') : '';
    \\      var cmp = 0;
    \\      if (type === 'num') {
    \\        cmp = parseFloat(aVal) - parseFloat(bVal);
    \\      } else {
    \\        cmp = aVal.localeCompare(bVal);
    \\      }
    \\      return dir === 'asc' ? cmp : -cmp;
    \\    });
    \\    // Update sort indicator classes on headers
    \\    var ths = table.querySelectorAll('thead th');
    \\    ths.forEach(function(th, i) {
    \\      th.classList.remove('sort-asc', 'sort-desc');
    \\      if (i === colIndex) th.classList.add(dir === 'asc' ? 'sort-asc' : 'sort-desc');
    \\    });
    \\    // Re-append sorted file rows and their corresponding detail rows together
    \\    rows.forEach(function(row) {
    \\      var fileId = row.dataset.fileId;
    \\      var detail = document.getElementById('detail-' + fileId);
    \\      tbody.appendChild(row);
    \\      if (detail) tbody.appendChild(detail);
    \\    });
    \\  };
    \\
    \\  // Expand/collapse file detail rows via event delegation
    \\  var fileTable = document.getElementById('file-table');
    \\  if (fileTable) {
    \\    fileTable.addEventListener('click', function(e) {
    \\      var row = e.target.closest('tr.file-row');
    \\      if (!row) return;
    \\      var fileId = row.dataset.fileId;
    \\      var detail = document.getElementById('detail-' + fileId);
    \\      if (!detail) return;
    \\      var expanded = detail.classList.toggle('expanded');
    \\      row.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    \\    });
    \\  }
    \\})();
;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Map score to CSS color class: ok (>=80), warning (>=50), error (<50)
fn scoreToColorClass(score: f64) []const u8 {
    if (score >= 80.0) return "ok";
    if (score >= 50.0) return "warning";
    return "error";
}

/// Map ThresholdStatus to CSS class string
fn statusToClass(status: ThresholdStatus) []const u8 {
    return switch (status) {
        .ok => "ok",
        .warning => "warning",
        .@"error" => "error",
    };
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
    try w.print("        <div class=\"health-score score-{s}\">{d:.0}</div>\n", .{
        color_class,
        project_score,
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

// ── File Table ────────────────────────────────────────────────────────────────

/// Write an inline metric bar: fill = min(100, value/error_threshold * 100)%
/// Thresholds for the default metrics (cyclomatic: warn=10,err=20; cognitive: warn=15,err=30; etc.)
fn writeMetricBar(w: anytype, value: f64, threshold_warning: f64, threshold_error: f64) !void {
    const pct = @min(@as(f64, 100.0), if (threshold_error > 0) value / threshold_error * 100.0 else 0.0);
    const status = if (value >= threshold_error) "error" else if (value >= threshold_warning) "warning" else "ok";
    try w.print("<div class=\"metric-bar\"><div class=\"metric-bar__fill {s}\" style=\"width:{d:.1}%\"></div></div>", .{ status, pct });
}

/// Write a single function row inside the nested function table
fn writeFunctionRow(w: anytype, r: ThresholdResult) !void {
    const health_class = scoreToColorClass(r.health_score);
    try w.writeAll("              <tr>\n");
    // Function name
    try w.writeAll("                <td data-value=\"");
    try writeHtmlEscaped(w, r.function_name);
    try w.writeAll("\">");
    try writeHtmlEscaped(w, r.function_name);
    try w.writeAll("</td>\n");
    // Kind
    try w.print("                <td data-value=\"{s}\">{s}</td>\n", .{ r.function_kind, r.function_kind });
    // Health score
    try w.print("                <td data-value=\"{d:.1}\"><span class=\"score-badge {s}\">{d:.0}</span></td>\n", .{
        r.health_score, health_class, r.health_score,
    });
    // Cyclomatic
    try w.writeAll("                <td data-value=\"");
    try w.print("{d}", .{r.complexity});
    try w.writeAll("\">");
    try w.print("{d}", .{r.complexity});
    try writeMetricBar(w, @as(f64, @floatFromInt(r.complexity)), 10.0, 20.0);
    try w.writeAll("</td>\n");
    // Cognitive
    try w.writeAll("                <td data-value=\"");
    try w.print("{d}", .{r.cognitive_complexity});
    try w.writeAll("\">");
    try w.print("{d}", .{r.cognitive_complexity});
    try writeMetricBar(w, @as(f64, @floatFromInt(r.cognitive_complexity)), 15.0, 30.0);
    try w.writeAll("</td>\n");
    // Halstead Volume
    try w.writeAll("                <td data-value=\"");
    try w.print("{d:.0}", .{r.halstead_volume});
    try w.writeAll("\">");
    try w.print("{d:.0}", .{r.halstead_volume});
    try writeMetricBar(w, r.halstead_volume, 500.0, 1000.0);
    try w.writeAll("</td>\n");
    // Halstead Difficulty
    try w.writeAll("                <td data-value=\"");
    try w.print("{d:.1}", .{r.halstead_difficulty});
    try w.writeAll("\">");
    try w.print("{d:.1}", .{r.halstead_difficulty});
    try writeMetricBar(w, r.halstead_difficulty, 15.0, 30.0);
    try w.writeAll("</td>\n");
    // Lines
    try w.writeAll("                <td data-value=\"");
    try w.print("{d}", .{r.function_length});
    try w.writeAll("\">");
    try w.print("{d}", .{r.function_length});
    try writeMetricBar(w, @as(f64, @floatFromInt(r.function_length)), 40.0, 80.0);
    try w.writeAll("</td>\n");
    // Params
    try w.writeAll("                <td data-value=\"");
    try w.print("{d}", .{r.params_count});
    try w.writeAll("\">");
    try w.print("{d}", .{r.params_count});
    try writeMetricBar(w, @as(f64, @floatFromInt(r.params_count)), 4.0, 8.0);
    try w.writeAll("</td>\n");
    // Nesting
    try w.writeAll("                <td data-value=\"");
    try w.print("{d}", .{r.nesting_depth});
    try w.writeAll("\">");
    try w.print("{d}", .{r.nesting_depth});
    try writeMetricBar(w, @as(f64, @floatFromInt(r.nesting_depth)), 3.0, 6.0);
    try w.writeAll("</td>\n");
    try w.writeAll("              </tr>\n");
}

/// Write the expandable detail row for a file (hidden by default)
fn writeDetailRow(w: anytype, file_result: FileThresholdResults, file_index: usize) !void {
    try w.print("      <tr class=\"detail-row\" id=\"detail-{d}\">\n", .{file_index});
    try w.writeAll("        <td colspan=\"4\">\n");
    try w.writeAll("          <div class=\"detail-inner\">\n");
    if (file_result.results.len == 0) {
        try w.writeAll("            <p style=\"color:var(--muted);font-size:0.8rem\">No functions found in this file.</p>\n");
    } else {
        try w.writeAll("            <table class=\"fn-table\">\n");
        try w.writeAll("              <thead><tr>\n");
        try w.writeAll("                <th>Function</th>\n");
        try w.writeAll("                <th>Kind</th>\n");
        try w.writeAll("                <th>Health</th>\n");
        try w.writeAll("                <th>Cyclomatic</th>\n");
        try w.writeAll("                <th>Cognitive</th>\n");
        try w.writeAll("                <th>Halstead Vol</th>\n");
        try w.writeAll("                <th>Halstead Diff</th>\n");
        try w.writeAll("                <th>Lines</th>\n");
        try w.writeAll("                <th>Params</th>\n");
        try w.writeAll("                <th>Nesting</th>\n");
        try w.writeAll("              </tr></thead>\n");
        try w.writeAll("              <tbody>\n");
        for (file_result.results) |r| {
            try writeFunctionRow(w, r);
        }
        try w.writeAll("              </tbody>\n");
        try w.writeAll("            </table>\n");
    }
    try w.writeAll("          </div>\n");
    try w.writeAll("        </td>\n");
    try w.writeAll("      </tr>\n");
}

/// Write a collapsed file summary row
fn writeFileRow(w: anytype, file_result: FileThresholdResults, file_index: usize) !void {
    const score = computeFileHealthScore(file_result.results);
    const score_class = scoreToColorClass(score);

    // Compute worst violation status
    var worst_status: ThresholdStatus = .ok;
    for (file_result.results) |r| {
        if (r.status == .@"error" or r.cognitive_status == .@"error" or
            r.halstead_volume_status == .@"error" or r.function_length_status == .@"error" or
            r.params_count_status == .@"error" or r.nesting_depth_status == .@"error")
        {
            worst_status = .@"error";
            break;
        } else if (r.status == .warning or r.cognitive_status == .warning or
            r.halstead_volume_status == .warning or r.function_length_status == .warning or
            r.params_count_status == .warning or r.nesting_depth_status == .warning)
        {
            worst_status = .warning;
        }
    }
    const worst_label = switch (worst_status) {
        .ok => "ok",
        .warning => "warning",
        .@"error" => "error",
    };

    try w.print("      <tr class=\"file-row\" data-file-id=\"{d}\" aria-expanded=\"false\">\n", .{file_index});
    // File path cell — full path in text, truncated visually via CSS with RTL ellipsis
    try w.writeAll("        <td data-value=\"");
    try writeHtmlEscaped(w, file_result.path);
    try w.writeAll("\"><span class=\"truncate\">");
    try writeHtmlEscaped(w, file_result.path);
    try w.writeAll("</span></td>\n");
    // Health score cell
    try w.print("        <td data-value=\"{d:.1}\"><span class=\"score-badge {s}\">{d:.0}</span></td>\n", .{
        score, score_class, score,
    });
    // Function count
    try w.print("        <td data-value=\"{d}\">{d}</td>\n", .{ file_result.results.len, file_result.results.len });
    // Worst violation
    try w.print("        <td data-value=\"{s}\"><span class=\"score-badge {s}\">{s}</span></td>\n", .{
        worst_label, worst_label, worst_label,
    });
    try w.writeAll("      </tr>\n");
}

/// Write the full file breakdown table with sortable headers and expandable rows
fn writeFileTable(w: anytype, file_results: []const FileThresholdResults) !void {
    if (file_results.len == 0) return;

    try w.writeAll("    <section class=\"file-table-section\">\n");
    try w.writeAll("      <h2>File Breakdown</h2>\n");
    try w.writeAll("      <table class=\"file-table\" id=\"file-table\">\n");
    try w.writeAll("        <thead>\n");
    try w.writeAll("          <tr>\n");
    try w.writeAll("            <th onclick=\"sortTable('file-table', 0, 'str')\">File Path</th>\n");
    try w.writeAll("            <th onclick=\"sortTable('file-table', 1, 'num')\">Health Score</th>\n");
    try w.writeAll("            <th onclick=\"sortTable('file-table', 2, 'num')\">Functions</th>\n");
    try w.writeAll("            <th onclick=\"sortTable('file-table', 3, 'str')\">Worst Violation</th>\n");
    try w.writeAll("          </tr>\n");
    try w.writeAll("        </thead>\n");
    try w.writeAll("        <tbody>\n");

    for (file_results, 0..) |fr, idx| {
        try writeFileRow(w, fr, idx);
        try writeDetailRow(w, fr, idx);
    }

    try w.writeAll("        </tbody>\n");
    try w.writeAll("      </table>\n");
    try w.writeAll("    </section>\n");
}

// ── TESTS ─────────────────────────────────────────────────────────────────────

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

test "writeMetricBar percentage clamping" {
    const allocator = std.testing.allocator;
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    // Value above error threshold: should clamp to 100%
    try writeMetricBar(w, 50.0, 10.0, 20.0);
    // Must contain width:100.0% (clamped)
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "width:100.0%") != null);

    buf.clearRetainingCapacity();

    // Value at exactly 0: should be 0%
    try writeMetricBar(w, 0.0, 10.0, 20.0);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "width:0.0%") != null);
}

test "file table row count" {
    const allocator = std.testing.allocator;

    const results1 = [_]ThresholdResult{
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
    const results2 = [_]ThresholdResult{
        .{
            .complexity = 3,
            .status = .ok,
            .function_name = "render",
            .function_kind = "arrow",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 2,
            .cognitive_status = .ok,
            .health_score = 90.0,
        },
    };
    const file_results = [_]FileThresholdResults{
        .{ .path = "src/app.ts", .results = &results1 },
        .{ .path = "src/ui.ts", .results = &results2 },
    };

    const html = try buildHtmlReport(
        allocator,
        &file_results,
        1,
        0,
        81.0,
        "0.5.0",
    );
    defer allocator.free(html);

    // Should have 2 file-row elements and 2 detail-row elements
    var count_file_row: usize = 0;
    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, html, search_pos, "class=\"file-row\"")) |pos| {
        count_file_row += 1;
        search_pos = pos + 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count_file_row);

    var count_detail_row: usize = 0;
    search_pos = 0;
    while (std.mem.indexOfPos(u8, html, search_pos, "class=\"detail-row\"")) |pos| {
        count_detail_row += 1;
        search_pos = pos + 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count_detail_row);
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

    // Must contain file table
    try std.testing.expect(std.mem.indexOf(u8, html, "file-table") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "file-row") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "detail-row") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "sortTable") != null);
}

// ── Treemap & Bar Chart ───────────────────────────────────────────────────────

/// Computed treemap tile coordinates in SVG space
const TreemapRect = struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    file_index: usize,
    score: f64,
};

/// Input weight + score for each file
const FileWeight = struct {
    index: usize,
    weight: f64,
    score: f64,
};

/// Return the last path component (after last '/'), truncated to max_len chars.
fn truncateFilename(path: []const u8, max_len: usize) []const u8 {
    // Find last '/'
    var start: usize = 0;
    var i: usize = 0;
    while (i < path.len) : (i += 1) {
        if (path[i] == '/') start = i + 1;
    }
    const name = path[start..];
    if (name.len <= max_len) return name;
    return name[0..max_len];
}

/// Squarified treemap algorithm (Bruls 1999).
/// items must be sorted descending by weight. Bounding box: (bx, by, bw, bh).
/// Returns heap-allocated slice of TreemapRect; caller owns memory.
fn squarify(allocator: Allocator, items: []const FileWeight, bx: f64, by: f64, bw: f64, bh: f64) ![]TreemapRect {
    var rects = std.ArrayList(TreemapRect).empty;
    errdefer rects.deinit(allocator);

    if (items.len == 0 or bw <= 0 or bh <= 0) return rects.toOwnedSlice(allocator);

    // Compute total weight
    var total_weight: f64 = 0.0;
    for (items) |item| {
        if (item.weight > 0) total_weight += item.weight;
    }
    if (total_weight <= 0) return rects.toOwnedSlice(allocator);

    const total_area = bw * bh;

    // We'll iterate over items, maintaining current bounding box
    var remaining_items = items;
    var cur_x = bx;
    var cur_y = by;
    var cur_w = bw;
    var cur_h = bh;
    var remaining_weight = total_weight;

    while (remaining_items.len > 0) {
        if (cur_w <= 0 or cur_h <= 0) break;
        if (remaining_weight <= 0) break;

        // Try to build a row. A "row" is a strip along the short edge.
        const short_side = @min(cur_w, cur_h);
        const row_area = short_side * short_side * remaining_weight / remaining_weight; // full strip area = short_side * long_side
        _ = row_area;

        // Find best row: add items greedily while aspect ratio improves
        const row_start: usize = 0;
        var row_end: usize = 0;
        var row_weight: f64 = 0.0;
        var best_ratio: f64 = std.math.floatMax(f64);

        // Available area for this strip
        const strip_area = short_side * (if (cur_w <= cur_h) cur_w else cur_h) * (remaining_weight / total_weight * total_area / (short_side * short_side));
        _ = strip_area;

        // Compute area available proportionally
        const available_area = cur_w * cur_h;

        var i: usize = 0;
        while (i < remaining_items.len) : (i += 1) {
            if (remaining_items[i].weight <= 0) {
                i += 1;
                // skip zero-weight items
                continue;
            }
            row_weight += remaining_items[i].weight;
            row_end = i + 1;

            // Compute worst aspect ratio in current row if we include item i
            const row_area_i = available_area * row_weight / remaining_weight;
            const row_len = if (cur_w <= cur_h) cur_w else cur_h;
            const row_strip = row_area_i / row_len;

            var worst: f64 = 0.0;
            var j: usize = row_start;
            while (j < row_end) : (j += 1) {
                if (remaining_items[j].weight <= 0) continue;
                const tile_area = available_area * remaining_items[j].weight / remaining_weight;
                const tile_len = if (row_strip > 0) tile_area / row_strip else 0;
                const r1 = if (tile_len > 0) row_strip / tile_len else std.math.floatMax(f64);
                const r2 = if (row_strip > 0) tile_len / row_strip else std.math.floatMax(f64);
                const ratio = @max(r1, r2);
                if (ratio > worst) worst = ratio;
            }

            if (worst <= best_ratio) {
                best_ratio = worst;
            } else {
                // Adding this item makes it worse; stop here
                row_weight -= remaining_items[i].weight;
                row_end = i;
                break;
            }
        }

        // If no items were added (e.g., first item is zero-weight), skip
        if (row_end == row_start) {
            remaining_items = remaining_items[1..];
            continue;
        }

        // Layout the row
        const row_area_final = available_area * row_weight / remaining_weight;
        const row_is_horizontal = cur_w > cur_h; // lay along wider dimension
        const row_len = if (row_is_horizontal) cur_h else cur_w;
        const row_strip = if (row_len > 0) row_area_final / row_len else 0;

        var offset: f64 = 0.0;
        var j: usize = row_start;
        while (j < row_end) : (j += 1) {
            if (remaining_items[j].weight <= 0) continue;
            const tile_frac = remaining_items[j].weight / row_weight;
            const tile_len = row_len * tile_frac;

            var rect: TreemapRect = undefined;
            if (row_is_horizontal) {
                // Strip runs vertically (left side), tiles stack horizontally within strip
                rect = .{
                    .x = cur_x,
                    .y = cur_y + offset,
                    .w = row_strip,
                    .h = tile_len,
                    .file_index = remaining_items[j].index,
                    .score = remaining_items[j].score,
                };
            } else {
                // Strip runs horizontally (top), tiles stack vertically within strip
                rect = .{
                    .x = cur_x + offset,
                    .y = cur_y,
                    .w = tile_len,
                    .h = row_strip,
                    .file_index = remaining_items[j].index,
                    .score = remaining_items[j].score,
                };
            }
            try rects.append(allocator, rect);
            offset += tile_len;
        }

        // Advance bounding box
        remaining_weight -= row_weight;
        remaining_items = remaining_items[row_end..];
        if (row_is_horizontal) {
            cur_x += row_strip;
            cur_w -= row_strip;
        } else {
            cur_y += row_strip;
            cur_h -= row_strip;
        }
    }

    return rects.toOwnedSlice(allocator);
}

/// Compare FileWeight items descending by weight (for sorting)
fn fileWeightDesc(_: void, a: FileWeight, b: FileWeight) bool {
    return a.weight > b.weight;
}

/// Write treemap SVG visualization
fn writeTreemap(w: anytype, allocator: Allocator, file_results: []const FileThresholdResults) !void {
    try w.writeAll("    <div class=\"viz-panel\">\n");
    try w.writeAll("      <h2>Complexity Treemap</h2>\n");

    // Collect file weights (skip 0-function files)
    var weights = std.ArrayList(FileWeight).empty;
    defer weights.deinit(allocator);

    for (file_results, 0..) |fr, idx| {
        if (fr.results.len == 0) continue;
        const score = computeFileHealthScore(fr.results);
        try weights.append(allocator, .{
            .index = idx,
            .weight = @as(f64, @floatFromInt(fr.results.len)),
            .score = score,
        });
    }

    if (weights.items.len == 0) {
        try w.writeAll("      <p style=\"color:var(--muted);font-size:0.8rem\">No files with functions to visualize.</p>\n");
        try w.writeAll("    </div>\n");
        return;
    }

    // Sort descending by weight
    std.sort.pdq(FileWeight, weights.items, {}, fileWeightDesc);

    const rects = try squarify(allocator, weights.items, 0, 0, 800, 400);
    defer allocator.free(rects);

    try w.writeAll("      <svg viewBox=\"0 0 800 400\" width=\"100%\" class=\"treemap\" role=\"img\" aria-label=\"File complexity treemap\">\n");

    for (rects) |rect| {
        const score = rect.score;
        const fill_color = if (score >= 80.0)
            "var(--color-ok-bg)"
        else if (score >= 50.0)
            "var(--color-warning-bg)"
        else
            "var(--color-error-bg)";

        try w.print("        <rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" fill=\"{s}\" opacity=\"0.75\" stroke=\"var(--bg)\" stroke-width=\"2\"/>\n", .{
            rect.x, rect.y, rect.w, rect.h, fill_color,
        });

        // Only add text if tile is large enough
        if (rect.w > 40 and rect.h > 20) {
            const fr = file_results[rect.file_index];
            const label = truncateFilename(fr.path, 18);
            const cx = rect.x + rect.w / 2.0;
            const cy = rect.y + rect.h / 2.0;
            try w.print("        <text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-size=\"10\" fill=\"white\">", .{ cx, cy });
            try writeHtmlEscaped(w, label);
            try w.writeAll("</text>\n");
        }
    }

    try w.writeAll("      </svg>\n");
    try w.writeAll("    </div>\n");
}

/// Compare FileThresholdResults by health score ascending (worst first)
fn fileScoreAsc(_: void, a: FileThresholdResults, b: FileThresholdResults) bool {
    return computeFileHealthScore(a.results) < computeFileHealthScore(b.results);
}

/// Write horizontal bar chart SVG, ranked by health score ascending (worst first)
fn writeBarChart(w: anytype, allocator: Allocator, file_results: []const FileThresholdResults) !void {
    try w.writeAll("    <div class=\"viz-panel\">\n");
    try w.writeAll("      <h2>Health Score Ranking</h2>\n");

    if (file_results.len == 0) {
        try w.writeAll("      <p style=\"color:var(--muted);font-size:0.8rem\">No files to visualize.</p>\n");
        try w.writeAll("    </div>\n");
        return;
    }

    // Copy and sort ascending by health score
    const sorted = try allocator.dupe(FileThresholdResults, file_results);
    defer allocator.free(sorted);
    std.sort.pdq(FileThresholdResults, sorted, {}, fileScoreAsc);

    const bar_height: u32 = 28;
    const label_width: u32 = 140;
    const bar_max_width: u32 = 600;
    const score_width: u32 = 45;
    const total_width: u32 = label_width + bar_max_width + score_width + 15;
    const svg_height: u32 = @intCast(sorted.len * bar_height + 10);

    try w.print("      <svg viewBox=\"0 0 {d} {d}\" width=\"100%\" class=\"bar-chart\" role=\"img\" aria-label=\"File health score ranking\">\n", .{ total_width, svg_height });

    for (sorted, 0..) |fr, idx| {
        const score = computeFileHealthScore(fr.results);
        const fill_color = if (score >= 80.0)
            "var(--color-ok)"
        else if (score >= 50.0)
            "var(--color-warning)"
        else
            "var(--color-error)";

        const y: u32 = @intCast(idx * bar_height + 5);
        const bar_w: u32 = @intFromFloat(score / 100.0 * @as(f64, @floatFromInt(bar_max_width)));
        const label = truncateFilename(fr.path, 20);

        // Label text
        try w.print("        <text x=\"{d}\" y=\"{d}\" text-anchor=\"end\" dominant-baseline=\"middle\" font-size=\"10\" fill=\"var(--muted)\">", .{ label_width - 4, y + bar_height / 2 });
        try writeHtmlEscaped(w, label);
        try w.writeAll("</text>\n");

        // Bar
        try w.print("        <rect x=\"{d}\" y=\"{d}\" width=\"{d}\" height=\"{d}\" fill=\"{s}\" opacity=\"0.8\" rx=\"2\"/>\n", .{
            label_width, y + 4, bar_w, bar_height - 8, fill_color,
        });

        // Score label
        try w.print("        <text x=\"{d}\" y=\"{d}\" dominant-baseline=\"middle\" font-size=\"10\" fill=\"var(--text)\">{d:.0}</text>\n", .{
            label_width + bar_w + 4, y + bar_height / 2, score,
        });
    }

    try w.writeAll("      </svg>\n");
    try w.writeAll("    </div>\n");
}

/// Write the visualizations section (treemap + bar chart) between dashboard and file table
fn writeVisualizations(w: anytype, allocator: Allocator, file_results: []const FileThresholdResults) !void {
    try w.writeAll("    <section class=\"visualizations\">\n");
    try writeTreemap(w, allocator, file_results);
    try writeBarChart(w, allocator, file_results);
    try w.writeAll("    </section>\n");
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
    try writeVisualizations(w, allocator, file_results);
    try writeFileTable(w, file_results);
    try w.writeAll("  </div>\n");
    try writeFooter(w, tool_version);
    try w.writeAll("  <script>\n");
    try w.writeAll(JS);
    try w.writeAll("  </script>\n");
    try w.writeAll("</body>\n</html>\n");

    return try allocator.dupe(u8, buf.items);
}

// ── Additional Visualization TESTS ────────────────────────────────────────────

test "squarify single item" {
    const allocator = std.testing.allocator;

    const items = [_]FileWeight{
        .{ .index = 0, .weight = 10.0, .score = 85.0 },
    };
    const rects = try squarify(allocator, &items, 0, 0, 800, 400);
    defer allocator.free(rects);

    try std.testing.expectEqual(@as(usize, 1), rects.len);
    // Single item should fill the whole viewbox
    try std.testing.expectEqual(@as(f64, 0.0), rects[0].x);
    try std.testing.expectEqual(@as(f64, 0.0), rects[0].y);
    // Width and height should cover the full area
    try std.testing.expect(rects[0].w > 0 and rects[0].h > 0);
}

test "squarify multiple items" {
    const allocator = std.testing.allocator;

    const items = [_]FileWeight{
        .{ .index = 0, .weight = 20.0, .score = 85.0 },
        .{ .index = 1, .weight = 15.0, .score = 60.0 },
        .{ .index = 2, .weight = 10.0, .score = 40.0 },
        .{ .index = 3, .weight = 5.0, .score = 90.0 },
    };
    const rects = try squarify(allocator, &items, 0, 0, 800, 400);
    defer allocator.free(rects);

    try std.testing.expectEqual(@as(usize, 4), rects.len);

    // All tiles must fit within viewbox
    for (rects) |rect| {
        try std.testing.expect(rect.x >= 0 and rect.y >= 0);
        try std.testing.expect(rect.x + rect.w <= 800.0 + 0.1); // small tolerance
        try std.testing.expect(rect.y + rect.h <= 400.0 + 0.1);
        try std.testing.expect(rect.w > 0 and rect.h > 0);
    }

    // Total area should approximately equal viewbox area
    var total_area: f64 = 0.0;
    for (rects) |rect| {
        total_area += rect.w * rect.h;
    }
    // Allow 1% tolerance
    try std.testing.expect(total_area > 800.0 * 400.0 * 0.99);
    try std.testing.expect(total_area < 800.0 * 400.0 * 1.01);
}

test "squarify skips zero-weight" {
    const allocator = std.testing.allocator;

    const items = [_]FileWeight{
        .{ .index = 0, .weight = 10.0, .score = 85.0 },
        .{ .index = 1, .weight = 0.0, .score = 70.0 }, // zero-weight: should be skipped
        .{ .index = 2, .weight = 5.0, .score = 50.0 },
    };
    const rects = try squarify(allocator, &items, 0, 0, 800, 400);
    defer allocator.free(rects);

    // Only 2 tiles expected (zero-weight skipped)
    try std.testing.expectEqual(@as(usize, 2), rects.len);
}

test "treemap SVG structure" {
    const allocator = std.testing.allocator;

    const results = [_]ThresholdResult{
        .{
            .complexity = 5,
            .status = .ok,
            .function_name = "foo",
            .function_kind = "function",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 2,
            .cognitive_status = .ok,
            .health_score = 85.0,
        },
    };
    const file_results = [_]FileThresholdResults{
        .{ .path = "src/foo.ts", .results = &results },
    };

    const html = try buildHtmlReport(
        allocator,
        &file_results,
        0,
        0,
        85.0,
        "0.5.0",
    );
    defer allocator.free(html);

    // Must contain treemap SVG elements
    try std.testing.expect(std.mem.indexOf(u8, html, "<svg") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<rect") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "treemap") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "bar-chart") != null);
}
