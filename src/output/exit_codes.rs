/// Exit code values matching the Zig binary semantics exactly.
///
/// Priority order (highest first):
/// 4 (ParseError) > 1 (ErrorsFound/baseline) > 2 (WarningsFound) > 0 (Success)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExitCode {
    /// Analysis completed with no issues
    Success = 0,
    /// Errors found, or baseline health check failed
    ErrorsFound = 1,
    /// Warnings found and --fail-on warning is set
    WarningsFound = 2,
    /// Config file is invalid or missing (reserved, not yet generated from analysis)
    ConfigError = 3,
    /// One or more files failed to parse
    ParseError = 4,
}

/// Determine the appropriate exit code based on analysis results.
///
/// Mirrors `determineExitCode` from exit_codes.zig.
/// Priority: ParseError(4) > baseline_failed/ErrorsFound(1) > WarningsFound(2) > Success(0).
///
/// The `fail_on` string controls whether warnings trigger a non-zero exit:
/// - "warning" → warnings cause WarningsFound(2)
/// - "none"    → always returns Success(0) regardless of errors or warnings
/// - "error" or absent → default behavior (errors cause 1, warnings are ok)
pub fn determine_exit_code(
    has_parse_errors: bool,
    error_count: u32,
    warning_count: u32,
    fail_on: Option<&str>,
    baseline_failed: bool,
) -> ExitCode {
    // "none" override: always succeed regardless of errors/warnings
    if fail_on == Some("none") {
        return ExitCode::Success;
    }

    // Parse errors take highest priority
    if has_parse_errors {
        return ExitCode::ParseError;
    }

    // Baseline failure or explicit errors
    if baseline_failed || error_count > 0 {
        return ExitCode::ErrorsFound;
    }

    // Warnings only trigger failure when --fail-on warning is set
    let fail_on_warnings = fail_on == Some("warning");
    if warning_count > 0 && fail_on_warnings {
        return ExitCode::WarningsFound;
    }

    ExitCode::Success
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_success_when_no_issues() {
        let code = determine_exit_code(false, 0, 0, None, false);
        assert_eq!(code, ExitCode::Success);
        assert_eq!(code as i32, 0);
    }

    #[test]
    fn test_errors_found_when_error_count_positive() {
        let code = determine_exit_code(false, 1, 0, None, false);
        assert_eq!(code, ExitCode::ErrorsFound);
        assert_eq!(code as i32, 1);
    }

    #[test]
    fn test_errors_found_when_multiple_errors() {
        let code = determine_exit_code(false, 5, 3, None, false);
        assert_eq!(code, ExitCode::ErrorsFound);
    }

    #[test]
    fn test_warnings_only_with_no_fail_on_is_success() {
        // Warnings alone do not cause failure without --fail-on warning
        let code = determine_exit_code(false, 0, 5, None, false);
        assert_eq!(code, ExitCode::Success);
    }

    #[test]
    fn test_warnings_with_fail_on_warning_causes_warnings_found() {
        let code = determine_exit_code(false, 0, 3, Some("warning"), false);
        assert_eq!(code, ExitCode::WarningsFound);
        assert_eq!(code as i32, 2);
    }

    #[test]
    fn test_parse_error_takes_priority_over_all() {
        // Parse error overrides everything else
        let code = determine_exit_code(true, 5, 3, Some("warning"), true);
        assert_eq!(code, ExitCode::ParseError);
        assert_eq!(code as i32, 4);
    }

    #[test]
    fn test_parse_error_takes_priority_over_errors() {
        let code = determine_exit_code(true, 10, 0, None, false);
        assert_eq!(code, ExitCode::ParseError);
    }

    #[test]
    fn test_baseline_failed_returns_errors_found() {
        let code = determine_exit_code(false, 0, 0, None, true);
        assert_eq!(code, ExitCode::ErrorsFound);
        assert_eq!(code as i32, 1);
    }

    #[test]
    fn test_fail_on_none_returns_success_despite_errors() {
        let code = determine_exit_code(false, 5, 3, Some("none"), false);
        assert_eq!(code, ExitCode::Success);
    }

    #[test]
    fn test_fail_on_none_returns_success_despite_baseline_failure() {
        let code = determine_exit_code(false, 0, 0, Some("none"), true);
        assert_eq!(code, ExitCode::Success);
    }

    #[test]
    fn test_fail_on_error_same_as_default() {
        // "error" behaves the same as None (default)
        let code_error = determine_exit_code(false, 0, 5, Some("error"), false);
        let code_none = determine_exit_code(false, 0, 5, None, false);
        assert_eq!(code_error, code_none);
        assert_eq!(code_error, ExitCode::Success);
    }

    #[test]
    fn test_fail_on_error_with_errors_found() {
        let code = determine_exit_code(false, 2, 0, Some("error"), false);
        assert_eq!(code, ExitCode::ErrorsFound);
    }

    #[test]
    fn test_exit_code_values() {
        assert_eq!(ExitCode::Success as i32, 0);
        assert_eq!(ExitCode::ErrorsFound as i32, 1);
        assert_eq!(ExitCode::WarningsFound as i32, 2);
        assert_eq!(ExitCode::ConfigError as i32, 3);
        assert_eq!(ExitCode::ParseError as i32, 4);
    }
}
