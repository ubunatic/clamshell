class Clamshell < Formula
  desc "CLI and daemon for managing your MacBook's sleep in clamshell mode"
  homepage "https://github.com/ubunatic/clamshell"
  url "https://github.com/ubunatic/clamshell/archive/refs/tags/v1.0.2.tar.gz"
  sha256 "7d5e09db67e75cf125590cd5e7e61c31a4d2913ada2af72a2964e13fda461a38"
  head "https://github.com/ubunatic/clamshell.git", branch: "main"
  depends_on :macos

  def install
    bin.install "clamshell.sh" => "clamshell"
    pkgshare.install "README.md"
  end

  def caveats
    <<~EOS
      You have installed 'clamshell' to manage your MacBook's clamshell mode.
      It comes with a launchd agent that runs in the background to monitor the lid state.

      To enable the launchd agent, run:

        clamshell install

      To disable the launchd agent, run:

        clamshell uninstall

      .----------------------------------------------.
      | ⚠️ Before removing the formula, make sure to  |
      |   'clamshell uninstall' the launchd agent!   |
      '----------------------------------------------'

    EOS
  end

  test do
    system "#{bin}/clamshell" "selftest"
  end
end
