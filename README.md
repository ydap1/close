# close

A fast macOS CLI to quit or kill all visible GUI apps in one shot.

## Install

```sh
git clone https://github.com/ydap1/close.git
cd close
./install.sh
```

To remove it:
```sh
./install.sh --uninstall
```

## Usage

```
close [options]
```

| Flag | Long form | Description |
|------|-----------|-------------|
| `-n` | `--dry-run` | Show targeted apps without closing anything |
| `-f` | `--force` | Graceful quit, then force-kill stragglers |
| `-F` | `--immediate` | SIGKILL everything immediately (no graceful quit) |
| `-b` | `--no-browser` | Skip web browsers |
| `-e NAME` | `--exclude NAME` | Skip a specific app (repeatable) |
| `-t SECS` | `--timeout SECS` | Seconds to wait after graceful quit (default: 2) |
| `-q` | `--quiet` | Suppress non-error output |
| `-v` | `--version` | Print version |
| `-h` | `--help` | Show help |

Short flags can be chained: `-fb` is the same as `-f -b`.  
Flags that take an argument (`-e`, `-t`) must come last in a chain.

## Examples

```sh
# See what would be closed (safe, nothing happens)
close -n

# Quit everything cleanly; force-kill anything that hangs
close -f

# Instant kill — no polite requests
close -F

# Force-quit everything except browsers and Slack
close -f -b -e Slack

# Force-quit, skip browsers, with a 5-second grace period
close -fbt 5

# Silent force-kill (useful in scripts)
close -Fq
```

## Excluded by default

Terminals are always excluded so the shell running `close` survives:
Terminal, iTerm2, Hyper, Alacritty, kitty, WezTerm.

With `-b` / `--no-browser`, these are also excluded:
Safari, Chrome, Firefox, Brave, Edge, Arc, Opera, Vivaldi, Tor Browser, Chromium.
