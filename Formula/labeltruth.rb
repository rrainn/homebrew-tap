# Homebrew formula for the LabelTruth CLI.
# Updated automatically by the release-cli workflow in rrainn/LabelTruth
# when a new v* tag is pushed.  Do NOT edit the version/sha256/url fields
# manually — the update-formula workflow will overwrite them.

require "json"
require "net/http"

# Custom download strategy that authenticates with GitHub API to download
# private repository release assets.  The default CurlDownloadStrategy
# cannot access private GitHub release assets; this converts the browser
# download URL into the GitHub API assets endpoint and attaches the user's
# HOMEBREW_GITHUB_API_TOKEN to the request.
class GitHubPrivateAssetDownloadStrategy < CurlDownloadStrategy
  # Override _fetch to authenticate against the GitHub API.
  # @param url [String] the browser download URL from the formula
  # @param resolved_url [String] unused; the API URL is derived from url instead
  # @param timeout [Integer, nil] download timeout forwarded to curl
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)
    raise CurlDownloadStrategyError,
          "HOMEBREW_GITHUB_API_TOKEN must be set to install labeltruth." unless token

    # Parse owner/repo/tag/filename from the GitHub release browser download URL
    match = url.match(%r{github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)})
    raise CurlDownloadStrategyError, "Unexpected URL format: #{url}" unless match

    owner, repo, tag, filename = match.captures

    # Look up the numeric asset ID via the GitHub REST API
    uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases/tags/#{tag}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "token #{token}"
      req["Accept"] = "application/vnd.github+json"
      http.request(req)
    end

    release = JSON.parse(response.body)
    asset = release["assets"]&.find { |a| a["name"] == filename }
    raise CurlDownloadStrategyError, "Asset #{filename} not found in release #{tag}" unless asset

    # Download via the GitHub API assets endpoint.
    # Accept: application/octet-stream causes GitHub to redirect to the S3 URL.
    asset_url = "https://api.github.com/repos/#{owner}/#{repo}/releases/assets/#{asset["id"]}"
    ohai "Downloading #{filename} via GitHub API"
    curl_download asset_url,
                  "--header", "Authorization: token #{token}",
                  "--header", "Accept: application/octet-stream",
                  to: temporary_path,
                  timeout: timeout
  end
end

class Labeltruth < Formula
  desc "CLI tool for LabelTruth workflows"
  homepage "https://github.com/rrainn/LabelTruth"
  version "0.0.6"

  depends_on "node"
  depends_on "python@3.13"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.6/labeltruth-cli-0.0.6-darwin-arm64.tar.gz",
          using: GitHubPrivateAssetDownloadStrategy
      sha256 "5ea6711bd561ee422cca88da94243d4f235167bed6a7f6315a7580986c0c2594"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.6/labeltruth-cli-0.0.6-darwin-x64.tar.gz",
          using: GitHubPrivateAssetDownloadStrategy
      sha256 "9eb614c340d8f849faf25e70236b426ea6f46b6d530ca7a86ce7e7c54021f479"
    end
  end

  on_linux do
    url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.6/labeltruth-cli-0.0.6-linux-x64.tar.gz",
        using: GitHubPrivateAssetDownloadStrategy
    sha256 "a7cc44cb9c85a0b7819d949436061f6f12592d5b3a10079e5208b60d41261add"
  end

  def worker_python_packages
    packages = %w[
      torch
      torchvision
      onnx
      onnxscript
      Pillow
      requests
      tensorboard
      tensorflow
      onnx2tf
      onnx2keras
      tensorflowjs
    ]

    # Core ML conversion is only available on macOS, so Linux workers skip it.
    packages << "coremltools" if OS.mac?
    packages
  end

  def worker_python
    libexec/"worker-python/bin/python3"
  end

  def python313
    Formula["python@3.13"].opt_bin/"python3.13"
  end

  def install
    # Homebrew strips the top-level directory when extracting tarballs, so the
    # build directory already contains dist/, node_modules/, package.json directly.
    libexec.install Dir["*"]

    # Keep all ML packages in one Python 3.13 environment so TensorFlow and
    # PyTorch import from the same interpreter without user shell config.
    system python313, "-m", "venv", libexec/"worker-python"
    system worker_python, "-m", "pip", "install", "--upgrade", "pip"
    system worker_python, "-m", "pip", "install", *worker_python_packages

    # TypeScript's compiler does not set the executable bit on output files.
    chmod 0755, libexec/"dist/bin/cli.js"

    # Set LABELTRUTH_PYTHON by default so worker users do not need shell config.
    # A user-supplied LABELTRUTH_PYTHON still wins for custom Python setups.
    (bin/"labeltruth").write <<~EOS
      #!/bin/bash
      export LABELTRUTH_PYTHON="${LABELTRUTH_PYTHON:-#{worker_python}}"
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/dist/bin/cli.js" "$@"
    EOS
    chmod 0755, bin/"labeltruth"
  end

  test do
    assert_match "labeltruth", shell_output("#{bin}/labeltruth --help")

    imports = %w[
      torch
      torchvision
      onnx
      onnxscript
      PIL
      requests
      tensorboard
      tensorflow
      onnx2tf
      onnx2keras
      tensorflowjs
    ]
    imports << "coremltools" if OS.mac?

    python_probe = <<~PYTHON
      import importlib
      for module_name in #{imports.inspect}:
          importlib.import_module(module_name)
    PYTHON
    system worker_python, "-c", python_probe
  end
end
