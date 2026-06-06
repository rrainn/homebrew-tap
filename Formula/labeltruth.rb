# Homebrew formula for the LabelTruth CLI.
# Updated automatically by the release-cli workflow in rrainn/LabelTruth
# when a new v* tag is pushed.  Do NOT edit the version/sha256/url fields
# manually — the update-formula workflow will overwrite them.

# Custom download strategy for private GitHub repositories.
# Homebrew's default curl download does not pass HOMEBREW_GITHUB_API_TOKEN
# when fetching release assets, so private repos return 404. This strategy
# adds an Authorization header using the token when available.
class GitHubPrivateRepositoryDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    @token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    args = [*curl_args(resolved_url, timeout: timeout)]
    args += ["--header", "Authorization: token #{@token}"] if @token
    args += ["--location", resolved_url]
    curl_download(*args, to: temporary_path)
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
          using: GitHubPrivateRepositoryDownloadStrategy
      sha256 "6a431ba54fc664c52162c8373223c22b26fefd3906e1e5e1338078dce291ef85"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-darwin-x64.tar.gz",
          using: GitHubPrivateRepositoryDownloadStrategy
      sha256 "901ba57dff2fa0f5b22dfe478a65f64b659c6beaaea9297217cfa181ec5d14ab"
    end
  end

  on_linux do
    url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-linux-x64.tar.gz",
        using: GitHubPrivateRepositoryDownloadStrategy
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
