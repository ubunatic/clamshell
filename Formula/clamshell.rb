class Clamshell < Formula
    desc "Clamshell manages your closed MacBook's sleep when an external display is attached."
    homepage "https://github.com/ubunatic/clamshell"
    url "https://github.com/ubunatic/clamshell/archive/refs/tags/v1.0.0.tar.gz"
    sha256 "323877459f1c1047d3437f73215e813cfe52ce5e0314671ef81429fa585c2e71"
    head "https://github.com/ubunatic/clamshell.git", branch: "main"
    depends_on :macos

    def install
      bin.install "clamshell.sh" => "clamshell"
      pkgshare.install "README.md"
    end

    test do
      system "#{bin}/clamshell" "selftest"
    end
end
