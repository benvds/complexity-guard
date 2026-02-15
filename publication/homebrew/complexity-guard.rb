# This formula is a template. SHA256 values are updated by the release workflow.

class ComplexityGuard < Formula
  desc "Fast complexity analysis for TypeScript/JavaScript"
  homepage "https://github.com/benvds/complexity-guard"
  version "0.1.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-aarch64-macos.tar.gz"
      sha256 "PLACEHOLDER_SHA256_AARCH64_MACOS"
    else
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-x86_64-macos.tar.gz"
      sha256 "PLACEHOLDER_SHA256_X86_64_MACOS"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-aarch64-linux.tar.gz"
      sha256 "PLACEHOLDER_SHA256_AARCH64_LINUX"
    else
      url "https://github.com/benvds/complexity-guard/releases/download/v#{version}/complexity-guard-x86_64-linux.tar.gz"
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
