class Clamshell < Formula
    desc "CLI for safely managing MacBook clamshell mode."
    homepage "https://github.com/ubunatic/clamshell"
    url "https://github.com/ubunatic/clamshell/archive/refs/tags/v1.0.0.tar.gz"
    sha256 "b4cab3956181528deeaf1b16bfb9dc10f2c2ed0532ce020058943d7df7339d3c"
    head "https://github.com/ubunatic/clamshell.git", branch: "main"

    def install
      bin.install "clamshell.sh" => "clamshell"
      pkgshare.install "README.md"
    end

    test do
      system "#{bin}/clamshell" "selftest"
    end
end
