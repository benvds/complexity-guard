/// ComplexityGuard library interface for external consumers (e.g. benchmarks).
/// Re-exports the core pipeline modules as public namespaces.
pub const walker = @import("discovery/walker.zig");
pub const parse = @import("parser/parse.zig");
pub const cyclomatic = @import("metrics/cyclomatic.zig");
pub const cognitive = @import("metrics/cognitive.zig");
pub const halstead = @import("metrics/halstead.zig");
pub const structural = @import("metrics/structural.zig");
pub const scoring = @import("metrics/scoring.zig");
pub const parallel = @import("pipeline/parallel.zig");
pub const duplication = @import("metrics/duplication.zig");
