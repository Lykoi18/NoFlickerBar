# NoFlickerBar

Stops the idle flicker of a faulty MacBook Pro Touch Bar. No SIP changes, no root,
no kernel extensions: a tiny user-level LaunchAgent.

## Symptom

The Touch Bar works fine while you use the Mac. A minute or so after you stop
touching it, it dims, then "goes dark", and instead of staying dark it shows a dim
glowing patch (often on the right) and then random bright flashes across the panel.
Touching a key brings it back to normal until the next idle period.

You may have searched for it as the Touch Bar **flickering**, **flashing**,
**glitching** or **blinking when idle**, or a Touch Bar that **glows or lights up
after it turns off**. It is reported mostly on 2016–2019 MacBook Pro models, and
Apple Diagnostics may show `DFR001`.

Overlay apps that paint the Touch Bar black do not help, because the problem is not
the content: it is the panel's lowest-power mode.

## How it works

On idle, `TouchBarServer` walks the panel through dimming steps:

| Idle time | TouchBarServer step | `DFRDimmingStep` | What you see |
|---|---|---|---|
| active | 0 | 1 | normal |
| keyboard backlight timeout (max 60 s) | 1 | 2 | dimmed |
| +15 s | 2 | **4** | "off": rendering stops, panel enters its low-power mode |

On affected panels step **4** is where the glow and flicker live. The panel is never
actually powered off here (`displayState` stays on).

`noflickerbar` polls the panel through Apple's private `DFRBrightness.framework`
(`DFRBrightnessClient`, the same client `TouchBarServer` uses) every 0.25 s. When it
sees step 4 it moves the panel back to step 2. Rendering is already off at that
point, so the Touch Bar just stays black. Any key or touch makes `TouchBarServer`
return to step 0 as usual, so Esc and the function row keep working.

It does nothing while the main display is asleep or the lid is closed, and it exits
cleanly on Macs without a Touch Bar.

## Resource usage

Polling four times a second sounds busy, but each poll is a couple of property reads
on the Touch Bar's HID service. Measured over 20 minutes on MacBookPro15,1
(i9-8950HK, macOS 15.8.1) with `ps` and `top`:

| Metric | Value |
|---|---|
| CPU | about 0.15 % of one core on average (1.8 s of CPU time in 19 min) |
| Idle wakeups | about 2 per second; macOS coalesces the timer with other work |
| Energy impact (`top` POWER) | 0.1–0.2 |
| Memory | 2.4 MB, 3 threads |

It adds no input latency: it does not tap or filter keyboard, trackpad or Touch Bar
events, and it only writes to the panel on idle transitions, a few times an hour.
To trade reaction time for even fewer wakeups, install with `POLL=0.5`.

## Requirements

MacBook Pro with a Touch Bar (2016–2022), Intel or Apple silicon.

Tested on MacBookPro15,1 (15-inch, 2018) with macOS 15.8.1. Reports from other
models are welcome.

## Install

Pick one. Each runs NoFlickerBar in the background and again at every login.

### Homebrew

```sh
brew tap lykoi18/noflickerbar https://github.com/Lykoi18/NoFlickerBar
brew trust lykoi18/noflickerbar   # Homebrew 7+ asks before using third-party taps
brew install noflickerbar
brew services start noflickerbar
```

Update with `brew upgrade noflickerbar`; remove with
`brew services stop noflickerbar && brew uninstall noflickerbar`.

### One-line installer

```sh
curl -fsSL https://raw.githubusercontent.com/Lykoi18/NoFlickerBar/main/install.sh | bash
```

It downloads the universal binary from the latest
[release](https://github.com/Lykoi18/NoFlickerBar/releases), checks its SHA-256,
copies it to `~/.local/bin/noflickerbar` and writes
`~/Library/LaunchAgents/io.github.lykoi18.noflickerbar.plist`. Read
[`install.sh`](install.sh) first if you prefer. Remove with:

```sh
curl -fsSL https://raw.githubusercontent.com/Lykoi18/NoFlickerBar/main/install.sh | bash -s -- --uninstall
```

To change the defaults described below, set them for `bash`, e.g.
`curl -fsSL …/install.sh | POLL=0.1 bash`.

### From source

Needs Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/Lykoi18/NoFlickerBar.git
cd NoFlickerBar
make install      # make uninstall to remove
```

Options:

```sh
make install POLL=0.1            # poll faster if you still catch a glimpse of the glow
make install DIM_STEP=1          # keep the idle panel at a brighter step (default 2)
make install BINDIR="$PWD/build" # run the binary from the repo instead of ~/.local/bin
```

## Diagnostics

```sh
log show --last 1h --predicate 'sender == "noflickerbar"'   # what the service did
dfrbright status      # displayState, DFRDimmingStep (Homebrew installs dfrbright too)
dfrbright watch 180   # print the state every second, then leave the Mac idle
```

From a source checkout use `make status` and `build/dfrbright`.

`dfrbright step <n>`, `dfrbright off` and `dfrbright on` drive the panel by hand.

## Limitations

- Uses private Apple frameworks. A macOS update can change them; `noflickerbar` then
  either keeps working, exits with "nothing to do", or needs an update.
- The panel can spend up to one poll interval (0.25 s by default) in step 4 before it
  is corrected, so a very brief glow is possible.
- This works around a hardware fault; it does not repair it. If the Touch Bar also
  misbehaves while active, run Apple Diagnostics (hold **D** at startup) and look for
  `DFR001`.

## Research notes

Things that do **not** keep the panel out of step 4:

- A blank system-modal Touch Bar (`NSTouchBar presentSystemModalTouchBar…`): the
  panel still enters step 4.
- `DFRSetDimmingStep` from `DFRFoundation`: a per-session rendering channel that
  does not touch `DFRDimmingStep`.
- Synthetic input (`CGEventPost`, `caffeinate -u`): resets `HIDIdleTime`, but
  `TouchBarServer` listens to `IOHIDEventSystem` activity and ignores it.
- Settings: the dim delay is `min(keyboard backlight timeout, 60 s)` and step 2 follows
  15 s later, both hard-coded in `/usr/libexec/TouchBarServer`.

## License

[MIT](LICENSE)
