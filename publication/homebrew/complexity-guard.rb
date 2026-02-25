# ComplexityGuard Homebrew Formula Template
#
# This is a TEMPLATE file, not a production formula.
#
# The PLACEHOLDER_SHA256_* values below are replaced during the release workflow
# by the `homebrew-update` job in `.github/workflows/release.yml`. The placeholders
# are substituted with actual SHA256 checksums computed from the binary archives.
#
# Placeholder names match Rust build target names:
#   - PLACEHOLDER_SHA256_AARCH64_MACOS  (matches aarch64-apple-darwin target)
#   - PLACEHOLDER_SHA256_X86_64_MACOS   (matches x86_64-apple-darwin target)
#   - PLACEHOLDER_SHA256_AARCH64_LINUX  (matches aarch64-unknown-linux-musl target)
#   - PLACEHOLDER_SHA256_X86_64_LINUX   (matches x86_64-unknown-linux-musl target)
#
# After the release workflow completes, copy this file to the Homebrew tap repository.
# See docs/releasing.md for the complete release process.

class ComplexityGuard < Formula
  desc "Fast complexity analysis for TypeScript/JavaScript"
  homepage "https://github.com/benvds/complexity-guard"
  version "0.1.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-aarch64-macos.tar.gz"
      # SHA256 computed by CI from complexity-guard-aarch64-macos.tar.gz
      sha256 "PLACEHOLDER_SHA256_AARCH64_MACOS"
    else
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-x86_64-macos.tar.gz"
      # SHA256 computed by CI from complexity-guard-x86_64-macos.tar.gz
      sha256 "PLACEHOLDER_SHA256_X86_64_MACOS"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-aarch64-linux.tar.gz"
      # SHA256 computed by CI from complexity-guard-aarch64-linux.tar.gz
      sha256 "PLACEHOLDER_SHA256_AARCH64_LINUX"
    else
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-x86_64-linux.tar.gz"
      # SHA256 computed by CI from complexity-guard-x86_64-linux.tar.gz
      sha256 "PLACEHOLDER_SHA256_X86_64_LINUX"
    end
  end

  def install
    bin.install "complexity-guard"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/complexity-guard --version")
  end
end
