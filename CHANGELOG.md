# Changelog

## 0.2.0 — 16 September 2026

### Auto-paste is now a switch you control

Choosing an entry used to always paste it into the app you were in, with no way to say
otherwise. There's now an **Auto-Paste** toggle in the menu bar and in Preferences. Turn it
off and ClipHistory only puts the entry on your clipboard — you press `Cmd+V` yourself,
whenever you like.

With it off, ClipHistory also stops asking for the Accessibility permission, since it no
longer needs it. The picker's footer says "copy" instead of "paste" whenever a paste isn't
going to happen, so what you see matches what you get.

### The picker can be tinted and made see-through

Two new settings in Preferences:

- **Picker opacity** — 25% to 100%
- **Picker background** — any colour you like, or the system default

Only the background fades, never the text, so the list stays readable all the way down to
25%. Pick a dark colour and the whole window switches to dark styling so the labels follow.

### Fixes

- **"Enable Auto-Paste…" now actually gets you somewhere.** It used to open System Settings
  without ever registering ClipHistory in the Accessibility list — so you'd arrive at a list
  with no ClipHistory row to tick. It also failed to bring System Settings forward when it
  was already running, which looked like the button doing nothing at all. Both fixed, and
  the deep link now targets the current macOS settings pane.
- **If you've ticked the box and ClipHistory still can't paste**, clicking the item a second
  time now explains why: macOS ties the permission to the app's signature, and `build.sh`
  signs ad-hoc, so every rebuild invalidates the previous grant. Remove ClipHistory from the
  list with `−`, add it back with `+`, or run `Tools/make-signing-cert.sh` once to stop it
  recurring.
- **Preferences no longer opens behind the picker.** It now sits above it, and the colour
  picker sits above both.
- The README said the shortcut was `Cmd+Shift+V`; it has been `Cmd+Option+V` since 0.1.0.

### Updating

```bash
git pull
./build.sh && ./install.sh
```

Your history, your shortcut and your settings are all kept. Note that rebuilding resets the
Accessibility permission unless you've set up stable signing — see the README.

## 0.1.0

First release. Menu bar clipboard history with a searchable picker, preview pane,
auto-paste, and a rebindable global shortcut.
