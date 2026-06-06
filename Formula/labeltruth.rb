# Homebrew formula for the LabelTruth CLI.
# Updated automatically by the release-cli workflow in rrainn/LabelTruth
# when a new v* tag is pushed.  Do NOT edit the version/sha256/url fields
# manually — the update-formula workflow will overwrite them.

require "json"
require "open-uri"

# Custom download strategy for private GitHub release assets.
# GitHub's browser download URLs do not accept token authentication.
# This strategy:
#   1. Parses the URL to extract owner/repo/tag/filename
#   2. Calls the GitHub API to get the release and find the numeric asset ID
#   3. Downloads using the API URL with token auth and Accept header
class GitHubPrivateReleaseDownloadStrategy < CurlDownloadStrategy
  private

  def _fetch(url:, resolved_url:, **kwargs)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token && resolved_url.include?("github.com")
      # Parse: github.com/{owner}/{repo}/releases/download/{tag}/{filename}
      match = resolved_url.match(
        %r{github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)}
      )
      if match
        owner, repo, tag, filename = match.captures

        # Fetch release metadata to get the numeric asset ID
        release_url = "https://api.github.com/repos/#{owner}/#{repo}/releases/tags/#{tag}"
        release_json = URI.open(release_url, "Authorization" => "token #{token}").read
        release = JSON.parse(release_json)

        asset = release["assets"]&.find { |a| a["name"] == filename }
        if asset
          asset_id = asset["id"]
          api_url = "https://api.github.com/repos/#{owner}/#{repo}/releases/assets/#{asset_id}"

          @curl_args += [
            "--header", "Authorization: token #{token}",
            "--header", "Accept: application/octet-stream",
          ]
          return super(url: url, resolved_url: api_url, **kwargs)
        else
          opoo "Asset #{filename} not found in release #{tag}"
        end
      end
    end
    super(url: url, resolved_url: resolved_url, **kwargs)
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
