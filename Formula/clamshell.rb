class Clamshell < Formula
    desc "Clamshell manages your closed MacBook's sleep when an external display is attached."
    homepage "https://github.com/ubunatic/clamshell"
    url "https://github.com/ubunatic/clamshell/archive/refs/tags/v1.0.0.tar.gz"
    sha256 "7558a1eaadcb2cddaf815d6a4e41ea1ce22d4f00e7ae798e65e68f632ebd35ce"
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
