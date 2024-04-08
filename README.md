Clamshell CLI
=============
Clamshell manages your MacBook's sleep when the lid is closed and an external display is attached.

- See `clamshell help` before using it.
- Read about [Clamshell Mode](#clamshell-mode) to learn why you may want to use it.

Disclaimer
----------
The `clamshell daemon` command and the provided LaunchAgent will try to continuously put MacOS to sleep if clamshell mode is detected. Please `clamshell uninstall` the agent before running OS updates and doing other system-critical work on your OS!

This software is provided "as is" (see [LICENSE](LICENSE)). \
Do not run this software if you are unsure how to stop and uninstall it! \
Do not run this software if you are unsure how to manually stop and remove it if it breaks!

Installation
------------
Install as Homebrew tap.
```sh
brew install ubunatic/clamshell/clamshell
```
Also see `brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

If you use `ssh` to access Github, manually `brew tap` this repo first.
```sh
brew tap ubunatic/clamshell git@github.com:ubunatic/clamshell.git
brew install ubunatic/clamshell/clamshell
```

Alternatively, just copy the [clamshell.sh](clamshell.sh) script to your `PATH` as `clamshell` binary.
```sh
cp clamshell.sh /usr/local/bin/clamshell
```

Setup the built-in bash/zsh completion.
```sh
# add this to your .zshrc
if type clamshell >/dev/null
then eval "$(clamshell complete)"
fi
```

See `clamshell help` for how to use it.

See [Agent Installation](#agent-installation) for how to install it as [MacOS launchd agent](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html).

Clamshell Mode
--------------
The Macbook's lid is also called clamshell [1](https://opensource.apple.com/source/xnu/xnu-2422.100.13/iokit/IOKit/pwr_mgt/IOPM.h.auto.html). The system in "clamshell mode" when the lid is closed and an external display is connected.

Closing the lid will not put the MacBook to sleep in this case. Putting it to sleep manually using a shortcut or command somehow works, but it is less convenient and - more importantly - not reliable!

Manual sleep works only once. Any accidental wake-up event will awake the MacBook, which will stay awake thereafter.

Accidental wakeups can be caused by mouse movements, keyboard presses, USB events, and more. The only way to keep the MacBook asleep is by closing the lid **and** unplugging all peripherals.

As of April 2024, MacOS does not have a power setting to put and keep the MacBook asleep when
the lid is closed. This is a long-standing issue that Apple has not addressed.

How it works
------------
MacBooks can detect if the lid is closed or not and will expose this in the [I/O Registry](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/TheRegistry/TheRegistry.html).
Using the `ioreg` command you can check the `AppleClamshellState` key in the registry.

- If the key is set to `Yes`, the lid is closed
- If the key is set to `No`, the lid is open

This tool runs this check and then uses the `pmset` power management CLI to initiate sleep.

- See `man pmset` for more details
- Also try running `pmset sleepnow` yourself

The `clamshell` CLI can be run manually or as "daemon"

- Run `clamshell sleep` to check for clamshell mode once and initiate sleep manually
- Run `clamshell daemon` to continuously check and sleep

Since you do not want to run this command everytime after closing the lid, you can [install](#agent-installation) the script as `clamshelld` launch agent. This will run the `clamshell sleep` logic continuously in the background as needed; and protected by some [Circuit Breakers](docs/development.md#circuit-breakers)

The agent will counter any accidental wakeups immediately and the MacBook stays asleep. To wake up the MacBook, you must open the lid then. Other attempts will be countered, since we cannot (yet) distinguish between desired and undesired wakeups.

Agent Installation
------------------
```sh
clamshell install    # installs the clamshelld agent
clamshell info       # show status info of agent
clamshell log        # attaches to the clamshelld log
clamshell unload     # disable the agent
clamshell load       # enable the agent
clamshell uninstall  # uninstalls the agent
```

The agent installation requires `sudo` permissions for creating the `plist` file in `$HOME/Library/LaunchAgents` and for copying the binary file to `$HOME/Library/Clamshell`. It will prompt you for your password.

See `clamshell help` for more daemon and agent commands and options.

Caveats
-------
### It's a hack!
This tool is a workaround and not a fix. It may not work in all cases and may have side effects. Apple may change their power management interface and system behavior anytime.

Please use it with caution and test it thoroughly before relying on it. Also see the [Disclaimer](#disclaimer).

During system sleep your monitor should go to sleep too and stay asleep. Other devices that are powered by the MacBook may still turn on occasionally, even if the MacBook is asleep. This is caused by the USB ports always delivering power. To truly power off all devices, you must still unplug them from the MacBook unfortunately.

### External Display Detection
Currently the tool relies on a naive active display count, which is flaky. When closing the lid, the display count query may still see the lid display as active and thus count it. The display count is effectively not used, except for some sanity checks:
- If the count is 0, nothing is done (system is sleeping or display detection broke)
- If the count is 1, this could mean that either the lid display is still on or another display is on. We cannot tell yet.
- IF the count is 2+, there are actually mutliple displays attached.

Anyway, as soon as we see one display while the lid is closed, sleep will be initiated. It would be better to safely count external displays only.

Ideas
-----
- Use `AppleClamshellCausesSleep` to not interfere with "good" (future) MacOS clamshell handling
- Use `IOPMPowerSource` and `ExternalConnected` to detect if in non-desktop mode (on battery) and never interfere then
- Use idle time to distinguish between desired and undesired wakeups
- Power off USB keyboard and mouse at inital sleep and at re-sleep after undesired wakeups