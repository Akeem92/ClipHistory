# ClipHistory

A small clipboard history manager for macOS. Lives in the menu bar, remembers what you
copy, and gives it back with a keyboard shortcut.

Written in Swift with AppKit, built with SwiftPM — no Xcode project, no storyboards.

## Features

- Remembers the last 500 text copies, restored on restart
- `Cmd+Shift+V` opens a searchable picker anywhere
- Multi-word search — `swift init` matches both words in any order
- Preview pane showing the full, unflattened content of the selected entry
- `Cmd+1`–`Cmd+9` pastes that entry directly
- `Cmd+Delete` forgets a single entry
- Pastes straight back into the app you were using
- Skips anything a password manager marks as concealed
- No Dock icon, no network access

## Requirements

- macOS 14 or later
- Swift 6.1 or later — `xcode-select --install` is enough, the full Xcode app is not needed

## Build and install

```bash
git clone <your-fork-url>
cd ClipHistory
./build.sh
./install.sh
```

`build.sh` compiles the package, assembles the `.app` bundle, renders the icon, and signs
it. `install.sh` copies the app to `~/Applications` and registers a launch agent so it
starts at login.

Then grant one permission — see below — and press `Cmd+Shift+V`.

## The Accessibility permission

Writing to the clipboard needs no permission. *Pressing `Cmd+V` for you* does, because
that means synthesizing a keyboard event, and macOS only allows trusted apps to do that.

**System Settings → Privacy & Security → Accessibility → enable ClipHistory**

Without it the app still works: choosing an entry puts it on the clipboard, you just press
`Cmd+V` yourself. The menu bar shows an "Enable Auto-Paste…" item while the permission is
missing.

## Shortcuts

| Key | Action |
| --- | --- |
| `Cmd+Shift+V` | Open the picker |
| `↑` `↓` | Move selection |
| `⏎` | Paste selected |
| `Cmd+1`–`Cmd+9` | Paste that row directly |
| `Cmd+Delete` | Forget selected entry |
| `esc` | Close |

The shortcut is stored in `UserDefaults`, so it can be rebound without recompiling.

## Security and privacy

A clipboard manager sees everything you copy, so it's worth being explicit about where
that goes.

- History is stored **unencrypted** as JSON at
  `~/Library/Application Support/ClipHistory/history.json`
- The file is `0600` and the folder `0700` — readable only by your user account
- Nothing is sent anywhere. The app makes no network requests and has no analytics
- Clipboard contents are never written to the system log
- Items tagged `org.nspasteboard.ConcealedType` are ignored. That's the convention
  password managers use to opt out of clipboard history, so 1Password and similar tools
  stay out of the file
- `Cmd+Delete` removes a single entry, and **Clear History** in the menu empties the file,
  for anything that wasn't tagged
- The storage folder is excluded from Time Machine, so clipboard contents aren't archived

If you copy secrets from tools that *don't* set the concealed flag — a token echoed in a
terminal, for instance — they will be recorded. Use `Cmd+Delete`.

## Optional: stable code signing

`build.sh` signs the app ad-hoc by default. Ad-hoc signatures change on every rebuild, and
macOS ties the Accessibility grant to the signature — so the permission resets each time
you rebuild.

`Tools/make-signing-cert.sh` creates a self-signed certificate to avoid that. **It adds a
trusted root certificate to your login keychain and will ask for your password.** It is
entirely optional; read it before running it. Without it the app works fine, you just
re-tick the checkbox occasionally.

## Uninstall

```bash
./uninstall.sh           # removes app + launch agent, keeps history
./uninstall.sh --purge   # also deletes the history file
```

## How it works

Four small pieces, if you want to read the code:

- **`ClipboardWatcher`** — macOS has no clipboard-changed notification, so it polls
  `NSPasteboard.changeCount` every 0.4s and reads the pasteboard when the number moves.
- **`HistoryStore`** — an in-memory array mirrored to JSON, with writes coalesced to at
  most one per second.
- **`PickerPanel`** — a floating `NSPanel` with a search field, results table and preview
  pane. It records the frontmost app *before* showing itself, since appearing makes
  ClipHistory frontmost.
- **`Paster`** — writes the pasteboard, reactivates the recorded app, then posts
  `Cmd+V` as a `CGEvent`.

`LSUIElement` in `Info.plist` is what makes it a background agent with no Dock icon.
`CFBundleIdentifier` there is the single source of truth — `build.sh`, `install.sh` and
`uninstall.sh` all read it, and the launch agent label is derived from it. Change it if you
fork, so two installs don't collide in `launchd`.

## Project layout

```
Package.swift              SwiftPM manifest
Info.plist                 bundle metadata; LSUIElement, bundle id
build.sh                   compile + assemble .app + sign
install.sh                 → ~/Applications + launch agent
uninstall.sh               reverse of install
Tools/make-icon.swift      draws the app icon (no binary assets in the repo)
Tools/make-signing-cert.sh optional stable signing identity
Sources/ClipHistory/
  ClipHistory.swift        @main, NSApplication setup
  AppDelegate.swift        wiring + menu bar
  ClipboardWatcher.swift   pasteboard polling
  HistoryStore.swift       storage
  PickerPanel.swift        the picker window
  Paster.swift             auto-paste
```

## Dependencies

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — global hotkey
registration and rebinding. MIT.

## License

MIT — see [LICENSE](LICENSE).
