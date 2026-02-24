pub mod exit_codes;

// Placeholder re-exports for future output submodules (Plans 02/03):
// pub mod console;
// pub mod json_output;
// pub mod sarif_output;
// pub mod html_output;

pub use exit_codes::{determine_exit_code, ExitCode};
