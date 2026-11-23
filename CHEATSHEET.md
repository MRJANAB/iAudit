# iOS USB Security & Storage — Cheat Sheet

A one-page reference for auditing a **USB-connected iPhone/iPad from a Mac or Linux
host, no jailbreak**, using `libimobiledevice`. Covers install, what you can do/fix,
storage keep-vs-delete, networking/traffic (app IN & OUT), and bundle-ID checks.

> **Authorization:** only for devices you own or are explicitly authorized to test.
> Uninstalling an app permanently deletes it and its data. Keep anything you copy
> off the device private. Never proxy a third party's banking/finance apps.

---

## 0. Install — four ways

| Method | Command |
|--------|---------|
| **Homebrew** (macOS) | `brew install libimobiledevice ideviceinstaller` (optionally `mitmproxy`) |
| **apt** (Debian/Ubuntu) | `sudo apt install libimobiledevice-utils ideviceinstaller usbmuxd` |
| **This repo's installer** | `git clone … && bash scripts/setup.sh` |
| **As a Claude Skill** | `git clone … ~/.claude/skills/iaudit` — Claude loads `SKILL.md` and runs the workflow on request |

> Note: this is packaged as a **Skill + CLI**, not an MCP server. The scripts are
> plain CLI, so they can be wrapped in an MCP server later if you want tool-call
> access — but nothing here requires one.

First connect: plug in a **data** cable, **unlock** the device, tap **Trust This
Computer** (re-tap after any reboot).

---

## 1. Connect & identify

```bash
idevice_id -l                                  # list connected UDIDs
idevicepair validate                           # confirm pairing
ideviceinfo -k DeviceName -k ProductType -k ProductVersion -k BuildVersion
idevicediagnostics restart                     # restart over USB
idevicediagnostics shutdown                    # power off over USB
```

---

## 2. Bundle IDs — what's installed (app "IN")

```bash
ideviceinstaller list --user                   # third-party apps (bundle id, version, name)
ideviceinstaller list --all                    # include Apple system apps
ideviceinstaller list --user -b com.app.id --xml   # one app's full Info.plist
```

**Check a single app's security posture** (permissions, ad SDKs, transport):
```bash
ideviceinstaller list --user -b com.app.id --xml | python3 scripts/apptriage.py
```

**Risk-rank every installed app:**
```bash
ideviceinstaller list --user --xml | python3 scripts/apptriage.py          # table
ideviceinstaller list --user --xml | python3 scripts/apptriage.py --json    # machine-readable
```

**Bundle-ID red flags to eyeball:**
- Display name ≠ bundle ID (e.g. "Network Scanner" = `com.spycamera.app`).
- Generic/odd vendors (`com.videobrowser.ios`, `com.paperclipglobal.*`).
- Third-party IPTV / "free utility" / "cleaner" / "VPN" apps — common adware.

---

## 3. What you CAN do / fix over USB

| Goal | How |
|------|-----|
| Inventory + risk-rank apps | `scripts/audit.sh` / `apptriage.py` |
| **Remove** a risky app | `ideviceinstaller uninstall com.app.id` (permanent) |
| Sideload an `.ipa` you own | `ideviceinstaller install app.ipa` |
| Pull crash reports | `idevicecrashreport -k ./crashes` |
| Full logical backup | `idevicebackup2 backup --full ./backup` |
| Copy photos/videos off | `afcclient get /DCIM ./out` |
| Watch live logs (per app) | `idevicesyslog -p AppName` |
| Capture network traffic | mitmproxy (§5) or pymobiledevice3 pcap |
| Restart the device | `idevicediagnostics restart` |

## 3b. What you CANNOT do over USB (hand to the user, on-device)

| Not possible | Where the user does it |
|--------------|------------------------|
| See per-app size / clear an app's cache | Settings → General → iPhone Storage |
| Clear Telegram/Snapchat/Instagram cache | In-app, or delete + reinstall |
| Read/remove config profiles, root CAs | Settings → General → VPN & Device Management; → About → Certificate Trust Settings |
| Change VPN / proxy / DNS | Settings → Wi-Fi → (i); Settings → VPN |
| Toggle Safari privacy settings | Settings → Apps → Safari |
| Screenshot (no Xcode DDI) | QuickTime → New Movie Recording → pick iPhone |

---

## 4. Storage — check, and what to delete vs keep

**Check free space (over USB):**
```bash
ideviceinfo -q com.apple.disk_usage | grep -E 'AmountDataAvailable|TotalDataCapacity'
```
`AmountDataAvailable` is the live free-space figure (the `TotalDataAvailable` one is
often a stale/cached value — ignore it).

**Per-app sizes are only in Settings → General → iPhone Storage.** Read the top of
that list — that's ground truth.

### Delete / clear
- 🗑 **Camera roll** (usually the #1 hog): offload with **Image Capture** → tick
  "Delete after import" (one step copies to Mac + removes from phone).
- 🧹 **App caches:** Telegram (Settings → Data and Storage → Clear Cache), Snapchat
  (Settings → Clear Cache), WhatsApp (Manage Storage).
- 📥 **Streaming downloads:** Netflix / Prime / YouTube offline videos.
- ⚠️ **Staged iOS update** ("iOS x.y.z" item): Settings → iPhone Storage → that item
  → Delete Update (re-downloads when you choose to update).
- 🔁 **Restart the phone** — flushes a few GB of **System Data** (purgeable cache).
- ❌ Adware/unused apps → `ideviceinstaller uninstall …`.

### Keep / don't delete
- ✅ **"iOS" (~20–25 GB)** — the operating system; not deletable, leave it.
- ✅ **Banking / finance / authenticator / gov-ID** apps and their data.
- ✅ **System Data** can't be deleted directly (only shrunk via restart + cache clears).
- ⚠️ **Offload ≠ clear cache:** Offload removes the app binary but **keeps** its data
  and cache. To actually wipe an app's cache with no in-app option → **Delete +
  reinstall**.

---

## 5. Networking — traffic IN & OUT, DNS, "firewall"

### Inspect outbound HTTPS (what an app sends)
```bash
mitmweb                     # proxy on :8080, UI on http://127.0.0.1:8081
```
On the device: Wi-Fi → network → Configure Proxy → Manual → host LAN IP : 8080.
Then Safari → `mitm.it` → install + fully trust the mitmproxy CA
(Settings → General → About → Certificate Trust Settings).
Open the app and watch requests. **Remove the CA + proxy when done.**

### Full packet capture (all traffic in AND out, no proxy)
- **pymobiledevice3** (`pip install pymobiledevice3`): captures device traffic to a
  pcap over the USB tunnel —
  ```bash
  pymobiledevice3 developer dvt sniff           # live, or
  pymobiledevice3 developer dvt pcap out.pcap    # save pcap, open in Wireshark
  ```
- **macOS + Xcode:** `rvictl -s <UDID>` creates a virtual interface `rvi0`, then
  `sudo tcpdump -i rvi0 -w out.pcap` (needs Xcode).

### DNS / proxy / VPN config (on-device check)
- Settings → Wi-Fi → (i) → **Configure Proxy** / **Configure DNS** — should be
  Off/Automatic unless you set them.
- Settings → **VPN** — only VPNs you installed (ad-blockers use a local VPN profile).

### "Firewall" on iOS — what's actually available
iOS has **no user-configurable host firewall**. Equivalents:
- **Content-blocker / VPN apps** (Lockdown, NextDNS, AdGuard, BlockBear) — filter or
  block domains via a local VPN profile.
- **Per-app Cellular toggle** — Settings → Cellular → turn off data for an app.
- **Screen Time → Content & Privacy Restrictions** — block categories/sites.
- **Lockdown Mode** (Settings → Privacy & Security) — aggressive attack-surface
  reduction for high-risk users.
You configure these on the device, not over USB.

---

## 6. Rogue-management / compromise checks

```bash
ideviceprovision list                                   # dev/enterprise profiles (0 = clean)
ideviceinfo -q com.apple.mobile.wireless_lockdown       # wifi/debug flags
ideviceinfo -k ActivationState                          # should be "Activated"
idevicecrashreport -k ./crashes                         # look for crash loops / panics
```
On-device: **VPN & Device Management** should show no unknown MDM/config profile;
**Certificate Trust Settings** should be empty (remove any mitmproxy CA you added).

---

## 7. Safe-cleanup workflow (recap)

1. `bash scripts/audit.sh --crash` → review risk-ranked apps.
2. Confirm each removal with the user → `ideviceinstaller uninstall com.app.id`.
3. Restart the phone (frees System Data).
4. Offload camera roll (Image Capture) + clear app caches on-device.
5. Verify: `ideviceinfo -q com.apple.disk_usage` and re-run the audit.
6. Hand off on-device checks (profiles, cert trust, Wi-Fi proxy/DNS, Safari).
