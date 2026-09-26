# Homebrew formula for the LabelTruth CLI.
# This file is rendered from the LabelTruth repository during release.
# Do not edit Formula/labeltruth.rb in the tap by hand; update this template or
# homebrew/worker-python-packages.json instead.

require "json"
require "net/http"

# Custom download strategy for private release assets. It prefers the GitHub API
# token path and falls back to the LabelTruth server proxy for worker hosts.
class GitHubPrivateAssetDownloadStrategy < CurlDownloadStrategy
  # Treat blank environment variables the same as missing ones.
  def env_value(name)
    value = ENV.fetch(name, nil)
    return nil if value.nil? || value.strip.empty?

    value
  end

  # Override _fetch to authenticate against the GitHub API.
  # @param url [String] the browser download URL from the formula
  # @param resolved_url [String] unused; the API URL is derived from url instead
  # @param timeout [Integer, nil] download timeout forwarded to curl
  def _fetch(url:, resolved_url:, timeout:)
    token = env_value("HOMEBREW_GITHUB_API_TOKEN")
    if token
      fetch_from_github(url, token, timeout)
    else
      fetch_from_labeltruth_proxy(url, timeout)
    end
  end

  # Download a private release asset directly from GitHub.
  def fetch_from_github(url, token, timeout)
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

  # Download a release asset through the authenticated LabelTruth server proxy.
  def fetch_from_labeltruth_proxy(url, timeout)
    proxy_url = resolve_labeltruth_proxy_url(url)
    headers = resolve_labeltruth_proxy_headers
    ohai "Downloading #{File.basename(URI(proxy_url).path)} via LabelTruth proxy"
    curl_download proxy_url, *headers, to: temporary_path, timeout: timeout
  end

  # Build the proxy URL from either a GitHub asset URL or a server-rendered URL.
  def resolve_labeltruth_proxy_url(url)
    return url if url.match?(%r{/api/ml-workers/cli-update/assets/[^/]+/[^/]+$})

    server_url = env_value("LABELTRUTH_URL")
    raise CurlDownloadStrategyError,
          "Set HOMEBREW_GITHUB_API_TOKEN or LABELTRUTH_URL plus LabelTruth worker auth to install labeltruth." unless server_url

    match = url.match(%r{github\.com/[^/]+/[^/]+/releases/download/([^/]+)/(.+)})
    raise CurlDownloadStrategyError, "Unexpected URL format: #{url}" unless match

    tag, filename = match.captures
    "#{server_url.sub(%r{/+$}, "")}/api/ml-workers/cli-update/assets/#{tag}/#{filename}"
  end

  # Return curl headers for the LabelTruth proxy without exposing token values.
  def resolve_labeltruth_proxy_headers
    update_token = env_value("LABELTRUTH_UPDATE_TOKEN")
    return ["--header", "X-Worker-Token: #{update_token}"] if update_token

    worker_token = env_value("LABELTRUTH_WORKER_TOKEN") || read_worker_token_from_config
    return ["--header", "X-Worker-Token: #{worker_token}"] if worker_token

    raise CurlDownloadStrategyError,
          "Set LABELTRUTH_UPDATE_TOKEN, LABELTRUTH_WORKER_TOKEN, or configure one LabelTruth worker before using the proxy."
  end

  # Read worker auth from the normal LabelTruth CLI config when unambiguous.
  def read_worker_token_from_config
    config_path = ENV.fetch("LABELTRUTH_CONFIG", File.join(Dir.home, ".labeltruth", "cli-config.json"))
    return nil unless File.exist?(config_path)

    config = JSON.parse(File.read(config_path))
    workers = config["workers"]
    return nil unless workers.is_a?(Hash) && !workers.empty?

    labeltruth_url = env_value("LABELTRUTH_URL")&.sub(%r{/+$}, "")
    candidates = workers.values.select do |worker|
      endpoint = worker["endpoint"].to_s.sub(%r{/+$}, "")
      labeltruth_url.nil? || endpoint == labeltruth_url
    end
    candidates = workers.values if candidates.empty? && workers.length == 1
    return nil unless candidates.length == 1

    candidates.first["token"]
  rescue JSON::ParserError
    nil
  end
end

class Labeltruth < Formula
  desc "CLI tool for LabelTruth workflows"
  homepage "https://github.com/rrainn/LabelTruth"
  version "0.0.226"

  depends_on "libffi" => :test
  depends_on "libnghttp3" => :test
  depends_on "libngtcp2" => :test
  depends_on "jq"
	depends_on "libsndfile"
  depends_on "sqlite" => :test
  depends_on "python@3.11"



  # ai-edge-litert ships Metal dylibs with @rpath install names that cannot be
  # expanded to Homebrew's absolute opt paths after wheel installation.
  preserve_rpath

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.226/labeltruth-cli-0.0.226-darwin-arm64.tar.gz",
          using: GitHubPrivateAssetDownloadStrategy
      sha256 "299076b814c5893084507577294141c364a0cfde7f4acac9305c8ed0a0d373e8"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.226/labeltruth-cli-0.0.226-darwin-x64.tar.gz",
          using: GitHubPrivateAssetDownloadStrategy
      sha256 "4a3c809bc1e8e14bddc683793457d67ba2e0e0b86bef4622dc7aa28547c7d1c2"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.226/labeltruth-cli-0.0.226-linux-arm64.tar.gz",
        using: GitHubPrivateAssetDownloadStrategy
      sha256 "1d61d127b0fe96fa9df627e2750f56176210ef71643389ffc8025c540e37c817"
    else
      url "https://github.com/rrainn/LabelTruth/releases/download/v0.0.226/labeltruth-cli-0.0.226-linux-x64.tar.gz",
        using: GitHubPrivateAssetDownloadStrategy
      sha256 "d3993367c6c634c777b629e624bcb033f56057b556b7c784e361a69063a187a9"
    end
  end

  def worker_python_packages
    packages = %w[
      numpy==1.26.4
      debugpy==1.8.21
      regex==2026.7.19
      huggingface-hub==0.36.2
      python-doctr==1.0.1
      transformers==4.49.0
      safetensors==0.5.3
      onnx==1.17.0
      onnxscript==0.2.6
      onnxruntime==1.20.1
      soundfile==0.13.1
      optuna==4.8.0
      Pillow==12.2.0
      pillow-heif==1.4.0
      rawpy==0.27.0
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
    packages << "torchaudio==2.2.2" if OS.mac?
    packages << "torchvision==0.17.2" if OS.mac?
    packages << "torch==2.2.2" if OS.linux? && Hardware::CPU.arm?
    packages << "torchaudio==2.2.2" if OS.linux? && Hardware::CPU.arm?
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
    packages << { package: "torch==2.6.0+cu124", extra_index_url: "https://download.pytorch.org/whl/cu124" } if OS.linux? && Hardware::CPU.intel?
    packages << { package: "torchaudio==2.6.0+cu124", extra_index_url: "https://download.pytorch.org/whl/cu124" } if OS.linux? && Hardware::CPU.intel?
    packages << { package: "torchvision==0.21.0+cu124", extra_index_url: "https://download.pytorch.org/whl/cu124" } if OS.linux? && Hardware::CPU.intel?
    packages
  end

  def worker_python_distribution_replacements
    replacements = []

    # Replace GUI-backed transitive wheels only after pip resolves their dependents.
    replacements << { package: "opencv-python-headless==4.11.0.86", distribution: "opencv-python-headless", module: "cv2", replaces: %w[opencv-python] } if OS.linux?
    replacements
  end

  def worker_python_imports
    imports = %w[
      numpy
      debugpy
      regex
      huggingface_hub
      doctr
      transformers
      safetensors
      onnx
      onnxscript
      onnxruntime
      soundfile
      optuna
      PIL
      pillow_heif
      rawpy
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
    imports << "torchaudio" if OS.mac?
    imports << "torchvision" if OS.mac?
    imports << "torch" if OS.linux? && Hardware::CPU.intel?
    imports << "torchaudio" if OS.linux? && Hardware::CPU.intel?
    imports << "torchvision" if OS.linux? && Hardware::CPU.intel?
    imports << "torch" if OS.linux? && Hardware::CPU.arm?
    imports << "torchaudio" if OS.linux? && Hardware::CPU.arm?
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

  def pip_binary_policy_args
    # Avoid caching large CUDA wheels and keep cryptography on binary wheels.
    ["--no-cache-dir", "--only-binary", "cryptography"]
  end

  def worker_python
    libexec/"worker-python/bin/python3"
  end

  def bundled_node
    libexec/"node/bin/node"
  end

  def bundled_node_version
    "24.19.0"
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
    # A failed download must not make Homebrew's recommended post-install retry fail earlier.
    rm_f constraint_file if constraint_file.exist?
    constraint_file.write worker_python_constraints.join("\n") + "\n"
    worker_python_custom_pip_packages.each do |package_config|
      pip_args = ["-m", "pip", "install", *pip_binary_policy_args, "--constraint", constraint_file]
      pip_args += ["--extra-index-url", package_config[:extra_index_url]] if package_config[:extra_index_url]
      # Fetch only the custom wheel here; resolve dependencies from public PyPI below.
      system worker_python, *pip_args, "--no-deps", package_config[:package]
    end
    custom_packages = worker_python_custom_pip_packages.map { |package_config| package_config[:package] }
    dependency_args = ["-m", "pip", "install", *pip_binary_policy_args, "--constraint", constraint_file]
    # Installed custom wheels satisfy these specs while pip obtains dependencies from public PyPI.
    system worker_python, *dependency_args, *custom_packages unless custom_packages.empty?
    system worker_python, "-m", "pip", "install", *pip_binary_policy_args, "--constraint", constraint_file, *worker_python_packages unless worker_python_packages.empty?
    worker_python_distribution_replacements.each do |replacement|
      # A clean owner transition avoids leaving overlapping cv2 wheel files behind.
      system worker_python, "-m", "pip", "uninstall", "--yes", *replacement[:replaces]
      system worker_python, "-m", "pip", "install", *pip_binary_policy_args, "--constraint", constraint_file, "--no-deps", replacement[:package]
    end
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
    chmod 0755, bundled_node

    # Set LABELTRUTH_PYTHON by default so worker users do not need shell config.
    # A user-supplied LABELTRUTH_PYTHON still wins for custom Python setups.
    (bin/"labeltruth").write <<~EOS
      #!/bin/bash
      export LABELTRUTH_PYTHON="${LABELTRUTH_PYTHON:-#{worker_python}}"
      export LABELTRUTH_JQ="${LABELTRUTH_JQ:-#{Formula["jq"].opt_bin/"jq"}}"
      if [[ "$OSTYPE" == "linux"* ]]; then
        # ONNX Runtime's CUDA provider needs CUDA libraries from Python wheels.
        for cuda_lib_dir in "#{libexec}/worker-python/lib"/python*/site-packages/nvidia/*/lib; do
          [[ -d "$cuda_lib_dir" ]] || continue
          case ":${LD_LIBRARY_PATH:-}:" in
            *:"$cuda_lib_dir":*) ;;
            *) export LD_LIBRARY_PATH="$cuda_lib_dir:${LD_LIBRARY_PATH:-}" ;;
          esac
        done
      fi
      if [[ "$OSTYPE" == "linux"* && -d "/usr/lib/wsl/lib" ]]; then
        # WSL stores the NVIDIA driver shim outside Homebrew's default loader path.
        case ":${LD_LIBRARY_PATH:-}:" in
          *:/usr/lib/wsl/lib:*) ;;
          *) export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}" ;;
        esac
      fi
      exec "#{bundled_node}" "#{libexec}/dist/bin/cli.js" "$@"
    EOS
    chmod 0755, bin/"labeltruth"
  end

  def post_install
    # Keep all ML packages in one interpreter without exposing user config.
    install_worker_python_environment
  end

  test do
    assert_match "labeltruth", shell_output("#{bin}/labeltruth --help")
    assert_match "v#{bundled_node_version}", shell_output("#{bundled_node} --version")

    # Verify native Node ML dependencies ship binaries for this Homebrew platform.
    native_node_probe = <<~JS
      require("#{libexec}/node_modules/onnxruntime-node");
      require("#{libexec}/node_modules/sharp");
    JS
    system bundled_node, "-e", native_node_probe

    # Exercise the installed tarball's real PDF.js/canvas tree with only synthetic document data.
    system bundled_node, libexec/"dist/smokes/localInferencePdfSmoke.js"

    replacement_probe_data = worker_python_distribution_replacements.map do |replacement|
      replacement.slice(:distribution, :module)
    end
    python_probe = <<~PYTHON
      import importlib
      import importlib.metadata
      for module_name in #{worker_python_imports.inspect}:
          importlib.import_module(module_name)
      package_owners = importlib.metadata.packages_distributions()
      for replacement in #{JSON.generate(replacement_probe_data)}:
          importlib.import_module(replacement["module"])
          owners = sorted(name.lower().replace("_", "-") for name in package_owners.get(replacement["module"], []))
          expected = [replacement["distribution"].lower().replace("_", "-")]
          if owners != expected:
              raise RuntimeError(f"{replacement['module']} owners were {owners}, expected {expected}")
    PYTHON
    system worker_python, "-c", python_probe

    capability_probe = <<~JS
      const { probePythonCapability } = require("#{libexec}/dist/commands/worker.js");
      probePythonCapability().then((capability) => {
          // The structured probe object itself is always truthy, so verify each release requirement.
          if (capability.pytorchTraining !== true) {
              throw new Error(`Worker did not advertise PyTorch training: ${JSON.stringify(capability)}`);
          }
          if (capability.doctrRecognition !== true) {
              throw new Error(`Worker did not advertise docTR recognition: ${JSON.stringify(capability)}`);
          }
          if (capability.layoutLmV3 !== true) {
              throw new Error(`Worker did not advertise LayoutLMv3: ${JSON.stringify(capability)}`);
          }
          console.log("Worker Python, docTR, and LayoutLMv3 capability preflight passed.");
      }).catch((error) => {
          console.error(error.message);
          process.exit(1);
      });
    JS
    with_env(LABELTRUTH_PYTHON: worker_python.to_s) do
      system bundled_node, "-e", capability_probe
    end

    # Load both immutable recognizer checkpoints and run the accurate PARSeq OCR preset before a release can publish.
    system worker_python, libexec/"dist/python/doctr-recognition-smoke.py"
  end
end
