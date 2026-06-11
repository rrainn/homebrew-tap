# Homebrew formula for the LabelTruth CLI.
# This file is rendered from the LabelTruth repository during release.
# Do not edit Formula/labeltruth.rb in the tap by hand; update this template or
# homebrew/worker-python-packages.json instead.

require "json"
require "net/http"

# Custom download strategy that authenticates with GitHub API to download
# private repository release assets. The default CurlDownloadStrategy cannot
# access private GitHub release assets.
class GitHubPrivateAssetDownloadStrategy < CurlDownloadStrategy
  # Override _fetch to authenticate against the GitHub API.
  # @param url [String] the browser download URL from the formula
  # @param resolved_url [String] unused; the API URL is derived from url instead
  # @param timeout [Integer, nil] download timeout forwarded to curl
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)
    raise CurlDownloadStrategyError,
          "HOMEBREW_GITHUB_API_TOKEN must be set to install labeltruth." unless token

    # Parse owner/repo/tag/filename from the GitHub release browser download URL.
    match = url.match(%r{github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)})
    raise CurlDownloadStrategyError, "Unexpected URL format: #{url}" unless match

    owner, repo, tag, filename = match.captures

    # Look up the numeric asset ID via the GitHub REST API.
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

    # Download via the GitHub API assets endpoint. Accept: application/octet-stream
    # causes GitHub to redirect to the S3 URL.
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
  version "0.0.15"

  depends_on "node"
  depends_on "libffi" => :test
  depends_on "libnghttp3" => :test
  depends_on "libngtcp2" => :test
  depends_on "sqlite" => :test
  depends_on "python@3.11"



  # ai-edge-litert ships Metal dylibs with @rpath install names that cannot be
  # expanded to Homebrew's absolute opt paths after wheel installation.
  preserve_rpath

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.15/labeltruth-cli-0.0.15-darwin-arm64.tar.gz",
          using: GitHubPrivateAssetDownloadStrategy
      sha256 "e4bc40a8229d9ff841b1c07867fc4957ef3159b0c9b5271109a88af2ec3707a7"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.15/labeltruth-cli-0.0.15-darwin-x64.tar.gz",
          using: GitHubPrivateAssetDownloadStrategy
      sha256 "441573e8e514fbde937ecb0f5b5d158dd69a1cb8049b2d916706e5430cbabdc8"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.15/labeltruth-cli-0.0.15-linux-arm64.tar.gz",
        using: GitHubPrivateAssetDownloadStrategy
      sha256 "79f7c5918ae2cc71d9085bff2d55095f31acef9101c793f7352bc0997afc4a87"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.15/labeltruth-cli-0.0.15-linux-x64.tar.gz",
        using: GitHubPrivateAssetDownloadStrategy
      sha256 "a3b5ff688a8db361a03dc7199a657b06c7b5b5e26ed1288375c743fd43eededf"
    end
  end

  def worker_python_packages
    packages = %w[
      onnx==1.17.0
      onnxscript==0.2.6
      Pillow==12.2.0
      requests==2.34.2
      tensorboard==2.15.2
      tensorflow==2.15.0
      tf_keras==2.15.0
      onnx-graphsurgeon==0.6.1
      psutil==7.2.2
      sng4onnx==2.0.1
      onnx2keras==0.0.24
    ]

    # Platform-specific package specs keep one manifest while matching wheel availability.
    packages << "torch==2.2.2" if OS.mac?
    packages << "torchvision==0.17.2" if OS.mac?
    packages << "torch==2.2.2" if OS.linux? && Hardware::CPU.arm?
    packages << "torchvision==0.17.2" if OS.linux? && Hardware::CPU.arm?
    packages << "ai-edge-litert==2.1.5" if OS.mac? && Hardware::CPU.arm?
    packages << "ai-edge-litert==1.0.1" if OS.mac? && Hardware::CPU.intel?
    packages << "ai-edge-litert==2.1.5" if OS.linux? && Hardware::CPU.intel?
    packages << "onnx2tf==1.28.8" if OS.mac?
    packages << "onnx2tf==1.28.8" if OS.linux? && Hardware::CPU.intel?
    packages << "tensorflowjs==4.22.0" if OS.mac?
    packages << "tensorflowjs==4.22.0" if OS.linux? && Hardware::CPU.intel?
    packages << "coremltools==9.0" if OS.mac?
    packages
  end

  def worker_python_custom_pip_packages
    packages = []

    # Some packages need a dedicated pip source, such as Linux CPU-only PyTorch.
    packages << { package: "torch==2.2.2+cpu", extra_index_url: "https://download.pytorch.org/whl/cpu" } if OS.linux? && Hardware::CPU.intel?
    packages << { package: "torchvision==0.17.2+cpu", extra_index_url: "https://download.pytorch.org/whl/cpu" } if OS.linux? && Hardware::CPU.intel?
    packages
  end

  def worker_python_imports
    imports = %w[
      onnx
      onnxscript
      PIL
      requests
      tensorboard
      tensorflow
      tf_keras
      onnx_graphsurgeon
      psutil
      sng4onnx
      onnx2keras
    ]

    # Platform-specific imports mirror wheel availability in the package manifest.
    imports << "torch" if OS.mac?
    imports << "torchvision" if OS.mac?
    imports << "torch" if OS.linux? && Hardware::CPU.intel?
    imports << "torchvision" if OS.linux? && Hardware::CPU.intel?
    imports << "torch" if OS.linux? && Hardware::CPU.arm?
    imports << "torchvision" if OS.linux? && Hardware::CPU.arm?
    imports << "ai_edge_litert" if OS.mac? && Hardware::CPU.arm?
    imports << "ai_edge_litert" if OS.mac? && Hardware::CPU.intel?
    imports << "ai_edge_litert" if OS.linux? && Hardware::CPU.intel?
    imports << "onnx2tf" if OS.mac?
    imports << "onnx2tf" if OS.linux? && Hardware::CPU.intel?
    imports << "tensorflowjs" if OS.mac?
    imports << "tensorflowjs" if OS.linux? && Hardware::CPU.intel?
    imports << "coremltools" if OS.mac?
    imports
  end

  def worker_python_constraints
    %w[
      chex==0.1.90
      flax==0.10.4
      jax==0.4.34
      jaxlib==0.4.34
      keras==2.15.0
      ml-dtypes==0.2.0
      numpy==1.26.4
      optax==0.2.5
      orbax-checkpoint==0.4.4
      packaging==23.2
      pandas==3.0.3
      protobuf==4.25.9
      scipy==1.17.1
      setuptools==81.0.0
      tensorboard-data-server==0.7.2
      tensorflow-decision-forests==1.8.1
      tensorflow-estimator==2.15.0
      tensorflow-hub==0.16.1
      tensorflow-io-gcs-filesystem==0.37.1
      tensorflow-macos==2.15.0
      tensorstore==0.1.45
    ]
  end

  def worker_python
    libexec/"worker-python/bin/python3"
  end

  def homebrew_python
    Formula["python@3.11"].opt_bin/"python3.11"
  end

  def install_worker_python_environment
    # Build the managed venv after Homebrew's linkage fixer has finished.
    rm_r libexec/"worker-python" if (libexec/"worker-python").exist?
    system homebrew_python, "-m", "venv", libexec/"worker-python"
    system worker_python, "-m", "pip", "install", "--upgrade", "pip"
    constraint_file = libexec/"worker-python-constraints.txt"
    constraint_file.write worker_python_constraints.join("\n") + "\n"
    worker_python_custom_pip_packages.each do |package_config|
      pip_args = ["-m", "pip", "install", "--constraint", constraint_file]
      pip_args += ["--extra-index-url", package_config[:extra_index_url]] if package_config[:extra_index_url]
      system worker_python, *pip_args, package_config[:package]
    end
    system worker_python, "-m", "pip", "install", "--constraint", constraint_file, *worker_python_packages unless worker_python_packages.empty?
  end

  def patch_compiled_worker_probe
    worker_js = libexec/"dist/commands/worker.js"
    worker_source = worker_js.read

    # Version 0.0.7 opens the WebSocket before the slow TensorFlow/CoreML probe.
    # Move the probe before socket creation so server auth timeouts do not fire.
    if worker_source.include?("void probeCapability()\n                        .then")
      worker_source = worker_source.sub(
        "    process.on('SIGINT', handleSignal);\n" \
        "    process.on('SIGTERM', handleSignal);\n" \
        "    // -- Reconnect loop with exponential back-off --------------------------------\n" \
        "    let backoffMs = 1000;\n",
        "    process.on('SIGINT', handleSignal);\n" \
        "    process.on('SIGTERM', handleSignal);\n" \
        "    // Probe before opening the socket so slow ML imports cannot consume the server auth timeout.\n" \
        "    const pytorchTrainingCapability = await probeCapability().catch(() => false);\n" \
        "    // -- Reconnect loop with exponential back-off --------------------------------\n" \
        "    let backoffMs = 1000;\n"
      )

      worker_source = worker_source.sub(
        "                const sendRegistration = (pytorchTraining) => {\n" \
        "                    currentWs.send(JSON.stringify({\n" \
        "                        type: 'register',\n" \
        "                        token,\n" \
        "                        capabilities: { pytorchTraining }\n" \
        "                    }));\n" \
        "                };\n" \
        "                currentWs.on('open', () => {\n" \
        "                    backoffMs = 1000; // reset on successful connect\n" \
        "                    void probeCapability()\n" \
        "                        .then((pytorchTraining) => sendRegistration(pytorchTraining))\n" \
        "                        .catch(() => sendRegistration(false));\n" \
        "                });\n",
        "                const sendRegistration = () => {\n" \
        "                    currentWs.send(JSON.stringify({\n" \
        "                        type: 'register',\n" \
        "                        token,\n" \
        "                        capabilities: { pytorchTraining: pytorchTrainingCapability }\n" \
        "                    }));\n" \
        "                };\n" \
        "                currentWs.on('open', () => {\n" \
        "                    backoffMs = 1000; // reset on successful connect\n" \
        "                    sendRegistration();\n" \
        "                });\n"
      )

      worker_js.open("w") { |file| file.write worker_source }
    end

    probe_js = libexec/"dist/shared/constants/pythonCapability.js"
    probe_source = probe_js.read

    # Keep the compiled 0.0.7 probe aligned with the full worker environment.
    if probe_source.include?("    \"tensorflow\",\n    \"onnx2tf\",")
      probe_js.open("w") do |file|
        file.write probe_source.sub(
          "    \"tensorflow\",\n    \"onnx2tf\",",
          "    \"tensorflow\",\n    \"tf_keras\",\n    \"onnx_graphsurgeon\",\n    \"psutil\",\n    \"ai_edge_litert\",\n    \"sng4onnx\",\n    \"onnx2tf\","
        )
      end
    end
  end

  def install
    # Homebrew strips the top-level directory when extracting tarballs, so the
    # build directory already contains dist/, node_modules/, package.json directly.
    libexec.install Dir["*"]

    patch_compiled_worker_probe

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

  def post_install
    # Keep all ML packages in one interpreter without exposing user config.
    install_worker_python_environment
  end

  test do
    assert_match "labeltruth", shell_output("#{bin}/labeltruth --help")

    # Verify native Node ML dependencies ship binaries for this Homebrew platform.
    native_node_probe = <<~JS
      require("#{libexec}/node_modules/onnxruntime-node");
      require("#{libexec}/node_modules/sharp");
    JS
    system Formula["node"].opt_bin/"node", "-e", native_node_probe

    python_probe = <<~PYTHON
      import importlib
      for module_name in #{worker_python_imports.inspect}:
          importlib.import_module(module_name)
    PYTHON
    system worker_python, "-c", python_probe

    capability_probe = <<~JS
      const { probePythonCapability } = require("#{libexec}/dist/commands/worker.js");
      probePythonCapability().then((ok) => {
          console.log(ok ? "true" : "false");
          process.exit(ok ? 0 : 1);
      });
    JS
    with_env(LABELTRUTH_PYTHON: worker_python.to_s) do
      system Formula["node"].opt_bin/"node", "-e", capability_probe
    end
  end
end
