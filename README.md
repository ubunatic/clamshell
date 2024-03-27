Clamshell CLI
=============
The `clamshell` CLI helps you put your MacBook to sleep and keep it asleep when the lid is closed. \
See `clamshell help` to learn how to use it.

Clamshell Mode
==============
A MacBook is in "clamshell mode" when the lid is closed and an external display is connected.

Closing the lid will not put the MacBook to sleep in this case. Putting it to sleep manually
using a shortcut or command somehow works, but it is a bad compromise, because it is less
convenient than just closing the lid and more importantly, it works only once. Any accidental
wake-up event will awake the MacBook and it will stay awake thereafter.

Accidental wake-ups can be caused by mouse movenments, keyboard presses, USB events, and more.
The only way to keep the MacBook asleep is by closing the lid and unplugging all peripherals.

As of April 2024, MacOS does not have a power setting to put and keep the MacBook asleep when
the lid is closed. This is a long-standing issue that Apple has not addressed.

How it works
============
MacBooks can detect if the lid is closed or not and will exposed this in the IORegistry.
Using the `ioreg` command you can check the `AppleClamshellState` key in the IORegistry.
If the key is set to `Yes`, the MacBook is in clamshell mode. The key is set to `No` otherwise.

This tool run this check and then uses the `pmset` power management CLI to initiate sleep.
See `man pmset` for more details. Also try running `pmset sleepnow` yourself.

The `clamshell` CLI can be run manually or as `clamshelld` daemon.
Run `clamshell sleep` to check for clamshell mode and initiate sleep.

Since you do not want to run this command everytime after closing the lid, you can install
`clamshelld` as a launchd service. This will run the `clamshell sleep` in the background
continuously as needed.

This way, any accidental wake-ups are immediately countered and the MacBook stays asleep.
To wake up the MacBook, you must open the lid then.

Installation
============
Run `clamshell install` to install the launchd service.
Run `clamshell uninstall` to uninstall the launchd service.
To check the status of the service, run `clamshell status`.
You can temporarily start and stop the service using `clamshell load` and `clamshell unload`.

The launchd service installation requires sudo permissions to create the service file
and will prompt you for your password. The service will be installed in your user's
Library/LaunchAgents folder and will be started automatically.

Also  see `clamshell help` for more commands and options.

Caveats
=======
This tool is a workaround and not a fix. It may not work in all cases and may have side effects.
Please use it with caution and test it thoroughly before relying on it.

During sleep you monitor should go to sleep and stay asleep. However, any devices that are powered
by the MacBook may still be turned on, even if the MacBook is asleep, since the USB ports are still
delivering power. To truly power off all devices, you must unplug them from the MacBook unfortunately.
