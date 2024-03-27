Clamshell CLI
=============
Clamshell manages your closed MacBook's sleep when an external display is attached. See `clamshell help` before using it and read about [Clamshell Mode](#clamshell-mode) to learn why you need it.

Basic Usage
-----------
Manual usage as self-contained script.
```sh
cp clamshell.sh $HOME/.local/bin/clamshell  # copy to PATH
clamshell help                              # use it
```

Or just install it - without putting it on the `PATH` - and let it do its job.
```sh
./clamshell.sh install  # installs the LaunchAgent
./clamshell.sh status   # show status of agent
```

Setup the built-in bash/zsh completion.
```sh
eval "$(clamshell complete)"  # add this to your .zshrc
```

Clamshell Mode
--------------
A MacBook is in "clamshell mode" when the lid is closed and an external display is connected.

Closing the lid will not put the MacBook to sleep in this case. Putting it to sleep manually
using a shortcut or command somehow works, but it is less convenient and - more importantly -
not reliable!

Manual sleep works only once. Any accidental wake-up event will awake the MacBook, which will
stay awake thereafter.

Accidental wakeups can be caused by mouse movements, keyboard presses, USB events, and more.
The only way to keep the MacBook asleep is by closing the lid and unplugging all peripherals.

As of April 2024, MacOS does not have a power setting to put and keep the MacBook asleep when
the lid is closed. This is a long-standing issue that Apple has not addressed.

How it works
------------
MacBooks can detect if the lid is closed or not and will expose this in the IORegistry.
Using the `ioreg` command you can check the `AppleClamshellState` key in the IORegistry.
If the key is set to `Yes`, the MacBook is in clamshell mode. The key is set to `No` otherwise.

This tool runs this check and then uses the `pmset` power management CLI to initiate sleep.
See `man pmset` for more details. Also try running `pmset sleepnow` yourself.

The `clamshell` CLI can be run manually or as `clamshell daemon`.
Run `clamshell sleep` to check for clamshell mode and initiate sleep manually.

Since you do not want to run this command everytime after closing the lid, you can install
the script as `clamshelld` LaunchAgent. This will run the `clamshell sleep` logic continuously in the background as needed.

The agent will counter any accidental wakeups immediately and the MacBook stays asleep.
To wake up the MacBook, you must open the lid then.

Installation
------------
Run `clamshell install` to install the LaunchAgent. \
Run `clamshell uninstall` to uninstall the LaunchAgent. \
Run `clamshell status` to check the status of the agent. \
You can temporarily start and stop the agent using `clamshell load` and `clamshell unload`.

The agent installation requires `sudo` permissions for creating the `plist` file
in `Library/LaunchAgents` and for copying the binary file to `Library/Clamshell`.
It will prompt you for your password.

See `clamshell help` for more daemon and agent commands and options.

Caveats
=======
This tool is a workaround and not a fix. It may not work in all cases and may have side effects. Apple may change their power management interface and behavior anytime.

Please use it with caution and test it thoroughly before relying on it.

During system sleep your monitor should go to sleep too and stay asleep.
Other devices that are powered by the MacBook may still turn on occasionally,
even if the MacBook is asleep, since the USB ports are still delivering power.
To truly power off all devices, you must still unplug them from the MacBook unfortunately.
