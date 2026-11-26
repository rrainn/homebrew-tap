class Rrainn < Formula
  desc "Command-line interface for rrainn"
  homepage "https://github.com/rrainn/homebrew-tap"
  version "1.0.0"
  depends_on macos: :ventura

  on_arm do
    url "https://github.com/rrainn/homebrew-tap/releases/download/rrainn-v1.0.0/rrainn-1.0.0-macos-arm64.tar.gz"
    sha256 "1ad1cc0fc9c1f73fafdb8e1f0f41450e81b56fa38f171c3f27c2a95760ceaa9a"
  end

  on_intel do
    url "https://github.com/rrainn/homebrew-tap/releases/download/rrainn-v1.0.0/rrainn-1.0.0-macos-x86_64.tar.gz"
    sha256 "95fcaf32c8c7dcaeb198eb4965a38eb2444d7b44772da8dfdc7921862832c142"
  end

  def install
    bin.install "rrainn"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/rrainn --version").strip
  end
end
