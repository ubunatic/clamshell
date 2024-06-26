class Clamshell < Formula
  desc "CLI and daemon for managing your MacBook's sleep in clamshell mode"
  homepage "https://github.com/ubunatic/clamshell"
  url "https://github.com/ubunatic/clamshell/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "4a07ed99f4ca75e252a74ebaa4fa6510848d86adbfada3ab16d3946ce47b1ddf"
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
