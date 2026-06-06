# Homebrew formula for the LabelTruth CLI.
# Updated automatically by the release-cli workflow in rrainn/LabelTruth
# when a new v* tag is pushed.  Do NOT edit the version/sha256/url fields
# manually — the update-formula workflow will overwrite them.

# Custom download strategy for private GitHub release assets.
# GitHub's browser download URLs do not accept token authentication.
# This strategy converts the URL to the GitHub API endpoint (which does
# accept tokens) and adds the required Accept header for binary downloads.
class GitHubPrivateReleaseDownloadStrategy < CurlDownloadStrategy
  private

  def _fetch(url:, resolved_url:, **kwargs)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token && resolved_url.include?("github.com")
      api_url = resolved_url.sub(
        %r{github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)},
        'api.github.com/repos/\1/\2/releases/assets/\4'
      )
      @curl_args += [
        "--header", "Authorization: token #{token}",
        "--header", "Accept: application/octet-stream",
      ]
    else
      api_url = resolved_url
    end
    super(url: url, resolved_url: api_url, **kwargs)
  end
end

class Labeltruth < Formula
  desc "CLI tool for LabelTruth workflows"
  homepage "https://github.com/rrainn/LabelTruth"
  version "0.0.4"

  depends_on "node"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-darwin-arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "6a431ba54fc664c52162c8373223c22b26fefd3906e1e5e1338078dce291ef85"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-darwin-x64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "901ba57dff2fa0f5b22dfe478a65f64b659c6beaaea9297217cfa181ec5d14ab"
    end
  end

  on_linux do
    url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-linux-x64.tar.gz",
        using: GitHubPrivateReleaseDownloadStrategy
    sha256 "74e5b8799e10a83e1cfd4ec142fcd803d860ac943902097bec052d5f206f253e"
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
