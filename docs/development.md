# Clamshell Development

## Contributing
- PRs are welcome
- All code must pass the `shellcheck` (run `make lint`)
- Use `test` instead of `[[ ... ]]` for simple tests (equality, empty, non-empty checks)
- Use `(( math test ))` for complex math conditions
- Use `(( math assignment ))` for doing math
- Use `local` for defining local variables
- Use `if`, `then`,  `elif`, `else`, `fi` instead of chaining `&&` and `||`
- Try to cover new features in the `clamshell-selftest()` function (self-contained test in [clamshell.sh](clamshell.sh))

## Development Steps
All features must be accessible through the [clamshell.sh](clamshell.sh) script!

- Before development, `clamshell uninstall` the LaunchAgent
- During development, use `./clamshell.sh COMMAND` to test all affected features
- Before committing, run `./clamshell.sh install` and then `clamshell COMMAND` to test again
- Run `clamshell selftest` and `make test` regularly

## Circuit Breakers
The MacOS LaunchAgent will run `clamshell daemon`, which tries to put the system to sleep continuously. If Apple changes how MacOS works in a very unexpected way, this may prevent the user from interacting with the system.

Therefore `clamshell daemon` excercises two *circuit breakers* to allow for stopping the daemon.

These circuit breakers must be tested regularly!

## Circuit Breaker 1: Idle Timeout
1. Run `clamshell idle` to check if the idle timeout is working
2. Run `clamshell load` and enter clamshell mode (close the lid) and wait 30 Seconds.
3. Press a key and start moving the mouse every 2 Seconds (keep the lid closed)
4. Login in to MacOS (typing your password also resets the idle timer)
5. Enter `clamshell unload` (you can stop moving the mouse now)
6. See `clamshell log` to observe idle handling.

## Circuit Breaker 2: Pause after Sleep
1. Run `clamshell load` and enter clamshell mode (close the lid)
2. After 5 Seconds, activate the system (keep the lid closed)
3. Login quickly (you have 30 Seconds in total)
4. Enter `clamshell unload`
5. Check `clamshell log` that the last message was *"waiting 30s after sleep attempt"*

## Untested Behavior: Active LaunchAgent during OS Update
Once installed the LaunchAgent will be active most of the time, with some pauses during reboot.

### Open Questions
1. How does this affect OS or regular software updates?
2. Can updates still finish in clamshell mode?
3. Which unexpected effects does the agent have in context of updates?

### How to test?
1. Start the LaunchAgent (`clamshell install`)
2. Start an OS update (incl. a scheduled restart)
3. Enter clamshell mode
4. Wake up the system and login a few times (keep lid closed)
5. Observe whether or not MacOS will stop/override the agent
6. Observe when the agent becomes active after boot
7. and whether or not it prevents some final update steps to be completed.

### Until we know better
Keep the lid open during updates or just `clamshell uninstall` before the update!
