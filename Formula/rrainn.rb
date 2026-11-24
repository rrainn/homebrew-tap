class Rrainn < Formula
  desc "Command-line interface for rrainn"
  homepage "https://github.com/rrainn/homebrew-tap"
  version "0.1.0"
  depends_on macos: :ventura

  on_arm do
    url "https://github.com/rrainn/homebrew-tap/releases/download/rrainn-v0.1.0/rrainn-0.1.0-macos-arm64.tar.gz"
    sha256 "93730e7241110e7bd2af77b06f4cfcf50f9c0282b9e95e7b9779dfa06a4a7b34"
  end

  on_intel do
    url "https://github.com/rrainn/homebrew-tap/releases/download/rrainn-v0.1.0/rrainn-0.1.0-macos-x86_64.tar.gz"
    sha256 "32f610bd497a4e9bd04978d69b843ca3a3ec27375be4348be27d17571cbf0410"
  end

  def install
    bin.install "rrainn"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/rrainn --version").strip
  end
end
