class Clamshell < Formula
    desc "CLI for safely managing MacBook clamshell mode."
    homepage "https://github.com/ubunatic/clamshell"
    url "https://github.com/ubunatic/clamshell.git", using: :git, tag: "v1.0.12"
    head "https://github.com/ubunatic/clamshell.git", branch: "main"

    def install
      bin.install "clamshell.sh" => "clamshell"
      pkgshare.install "README.md"
    end

    test do
      system "#{bin}/clamshell" "selftest"
    end
end
