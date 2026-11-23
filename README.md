# ios-usb-security-audit

A **Claude Code / Agent Skill** (and standalone CLI scripts) to security- and
storage-audit a **USB-connected iPhone or iPad from a Mac or Linux host — without a
jailbreak**, using the open-source [libimobiledevice](https://libimobiledevice.org)
suite.

It talks to Apple's own lockdown / AFC / installation services, so it works on
current iOS. It is confined to what those services expose (app **metadata**, not
sandbox contents) — see [`references/capabilities.md`](references/capabilities.md).

## What it does
- Enumerates installed apps and **risk-ranks** each one from its declared
  `Info.plist`: App Transport Security disabled (cleartext HTTP), ad/tracking SDKs
  (AdMob/Facebook), ad-driven sensitive permissions, and display-name vs bundle-ID
  mismatches (e.g. a "Network Scanner" whose bundle ID is `com.spycamera.app`).
- Reports **storage** usage and **crash reports**.
- Checks for **rogue provisioning/MDM profiles** and wireless-lockdown settings.
- Lets you **safely uninstall** flagged apps (explicit, per-app).

## Quick start
```bash
# 1. Install the toolchain (macOS/Homebrew or Debian/apt)
bash scripts/setup.sh

# 2. Connect the device over USB, unlock it, tap "Trust This Computer"
idevice_id -l            # should print a UDID

# 3. Run the audit (add --crash to also pull crash reports)
bash scripts/audit.sh --crash
```

Run the app triage on its own:
```bash
ideviceinstaller list --user --xml | python3 scripts/apptriage.py
```

## Using it as a Claude Skill
Drop this folder into your skills directory (e.g.
`~/.claude/skills/ios-usb-security-audit/`). Claude loads [`SKILL.md`](SKILL.md)
and runs the workflow when you ask it to "security-check / audit my connected
iPhone". It requires nothing but the scripts here plus `libimobiledevice`.

## Requirements
- macOS (Homebrew) or Linux (apt); Python 3.6+ (standard library only).
- `libimobiledevice` + `ideviceinstaller` (installed by `scripts/setup.sh`).
- A data USB cable; the device unlocked and paired ("Trust This Computer").

## Limits (non-jailbroken)
Per-app sizes, cache contents, installed config profiles / trusted CAs, and
screenshots are **not** reachable over USB — the scripts tell you which checks to do
in the device's Settings. Full detail in
[`references/capabilities.md`](references/capabilities.md).

## ⚠️ Authorization
For devices you **own or are explicitly authorized to test** only. Uninstalling an
app permanently deletes it and its data. Treat anything copied off the device as
private. Do not proxy a third party's banking/finance apps.

## License
MIT — see [LICENSE](LICENSE).
