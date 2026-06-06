# Homebrew formula for the LabelTruth CLI.
# Updated automatically by the release-cli workflow in rrainn/LabelTruth
# when a new v* tag is pushed.  Do NOT edit the version/sha256/url fields
# manually — the update-formula workflow will overwrite them.

require "json"
require "uri"
require "net/http"

class Labeltruth < Formula
  desc "CLI tool for LabelTruth workflows"
  homepage "https://github.com/rrainn/LabelTruth"
  version "0.0.4"

  depends_on "node"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-darwin-arm64.tar.gz"
      sha256 "6a431ba54fc664c52162c8373223c22b26fefd3906e1e5e1338078dce291ef85"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-darwin-x64.tar.gz"
      sha256 "901ba57dff2fa0f5b22dfe478a65f64b659c6beaaea9297217cfa181ec5d14ab"
    end
  end

  on_linux do
    url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.4/labeltruth-cli-0.0.4-linux-x64.tar.gz"
    sha256 "74e5b8799e10a83e1cfd4ec142fcd803d860ac943902097bec052d5f206f253e"
  end

  # Override fetch to download with GitHub token auth for private repo assets.
  # The default CurlDownloadStrategy doesn't pass HOMEBREW_GITHUB_API_TOKEN
  # when fetching release asset URLs, causing 404s on private repositories.
  # This converts the browser URL to the GitHub API endpoint (which accepts
  # token auth) and downloads using curl with the proper headers.
  def fetch
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    return super unless token

    download_url = stable.url
    match = download_url.match(
      %r{github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)}
    )
    return super unless match

    owner, repo, tag, filename = match.captures

    # Fetch release metadata to get the numeric asset ID
    uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases/tags/#{tag}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "token #{token}"
      request["Accept"] = "application/vnd.github+json"
      http.request(request)
    end

    release = JSON.parse(response.body)
    asset = release["assets"]&.find { |a| a["name"] == filename }
    return super unless asset

    asset_url = "https://api.github.com/repos/#{owner}/#{repo}/releases/assets/#{asset["id"]}"

    ohai "Downloading #{filename} with GitHub token authentication"
    curl_download asset_url,
                  "--header", "Authorization: token #{token}",
                  "--header", "Accept: application/octet-stream",
                  to: cached_download
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
