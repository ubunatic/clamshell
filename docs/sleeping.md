# MacOS Sleep - Development Notes

## How to convince powerd to sleep better?
Also see `man pmset` for more details.
Testing pmset changes:
```
sudo pmset -a tcpkeepalive 0   # changes setting, shows a warning
sudo pmset -a ttyskeepawake 0  # changes setting
sudo pmset -a acwake 0         # has no effect
sudo pmset -a sleep 1          # does not change the exclusions for powerd  and bluetoothd
sudo pmset -a ring 0           # has no effect
```

```
pmset -g before:                                                    | pmset -g after:
  System-wide power settings:                                       |   System-wide power settings:
   SleepDisabled          0                                         |    SleepDisabled          0
   DestroyFVKeyOnStandby  1                                         |    DestroyFVKeyOnStandby  1
  Currently in use:                                                 |   Currently in use:
   standby               1                                          |    standby               1
   Sleep On Power Button 1                                          |    Sleep On Power Button 1
   hibernatefile        /var/vm/sleepimage                          |    hibernatefile        /var/vm/sleepimage
   powernap             1                                           |    powernap             1
   networkoversleep     0                                           |    networkoversleep     0
   disksleep            10                                          |    disksleep            10
   sleep                1 (sleep prevented by powerd, bluetoothd)   |    sleep                1 (sleep prevented by powerd, bluetoothd)
   hibernatemode        3                                           |    hibernatemode        3
   ttyskeepawake        1                                           |    ttyskeepawake        0
   displaysleep         90                                          |    displaysleep         90
   tcpkeepalive         1                                           |    tcpkeepalive         0
   lowpowermode         0                                           |    lowpowermode         0
   womp                 0                                           |    womp                 0
```
