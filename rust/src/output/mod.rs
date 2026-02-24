pub mod console;
pub mod exit_codes;

// Placeholder re-exports for future output submodules (Plan 03):
// pub mod sarif_output;
// pub mod html_output;

pub use console::render_console;
pub use exit_codes::{determine_exit_code, ExitCode};
