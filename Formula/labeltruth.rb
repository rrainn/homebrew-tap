# Homebrew formula for the LabelTruth CLI.
# Updated automatically by the release-cli workflow in rrainn/LabelTruth
# when a new v* tag is pushed.  Do NOT edit the version/sha256/url fields
# manually — the update-formula workflow will overwrite them.
class Labeltruth < Formula
  desc "CLI tool for LabelTruth workflows"
  homepage "https://github.com/rrainn/LabelTruth"
  version "0.1.0"

  depends_on "node@22"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.1.0/labeltruth-cli-0.1.0-darwin-arm64.tar.gz"
      sha256 "PLACEHOLDER_DARWIN_ARM64"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.1.0/labeltruth-cli-0.1.0-darwin-x64.tar.gz"
      sha256 "PLACEHOLDER_DARWIN_X64"
    end
  end

  on_linux do
    url "https://github.com/rrainn/LabelTruth/releases/download/v0.1.0/labeltruth-cli-0.1.0-linux-x64.tar.gz"
    sha256 "PLACEHOLDER_LINUX_X64"
  end

  def install
    libexec.install Dir["*"]
    # The shebang in dist/bin/cli.js is #!/usr/bin/env node, so the symlink
    # resolves correctly when Node.js is installed via Homebrew.
    bin.install_symlink libexec/"dist/bin/cli.js" => "labeltruth"
  end

  test do
    assert_match "labeltruth", shell_output("#{bin}/labeltruth --help")
  end
end