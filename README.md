# bastion-script

> **Battle-tested Windows Server VPS hardening script.**
> Born from a real RDP brute-force compromise, the recovery, and the lessons.

A PowerShell script that takes a fresh Windows Server VPS from "default-and-vulnerable" to "hardened" in about 15 minutes. Single file, no dependencies, opinionated defaults, safety nets so you don't lock yourself out.

**Tested on Windows Server 2016, 2019, 2022, and 2025.**

---

## The story

I bought a Contabo VPS for an automated trading setup. Within **3 hours of going online**, the RDP service was being brute-forced by botnets — 400+ failed login attempts in the first hour, from notorious IP ranges (`3.65.40.162`, `45.133.195.x`, `181.215.65.x`).

The server got slow. CPU pegged at 50%+. I thought it was my trading software. It wasn't — it was `TermService` (the RDP service) consuming 2,400+ CPU seconds just handling brute-force authentication attempts. By the time I noticed, an attacker had an established TCP connection on port 3389 and was actively trying credentials.

I closed off RDP, audited the server, and decided to reinstall rather than try to clean up — you can never prove a Windows Server is clean once attackers had an established connection.

Then I rebuilt it properly. **This script is the result.**

---

## What it does

A single PowerShell script that performs every step a hardening guide tells you to do, in the right order, with safety checks between destructive actions.

### Account hygiene
- Create a new admin account with a strong password (you specify the name)
- Disable the default `Administrator` account (only after verifying replacement works)
- Disable `Guest`, `DefaultAccount`, cloud-provider provisioning accounts
- Set account lockout policy (5 failed attempts → 30 min lockout)
- Enforce 14+ character passwords with complexity requirements

### RDP hardening
- Detect your current public IP and restrict RDP to it
- Move RDP off the default port `3389` to a randomized high port
- Verify Network Level Authentication (NLA) is enabled
- Add public-IP fallback rule **before** disabling broader access (the safety net pattern)
- Force `TermService` startup to `Automatic` (default `Manual` causes lockouts after reboot)

### Firewall lockdown
- Disable rules for protocols you don't need: `mDNS`, `Cast to Device`, `AllJoyn`, `Microsoft Edge networking`, `Wireless Display`, `Media Foundation`, `Delivery Optimization`
- Disable `WinRM` (service + firewall + listener + `LocalAccountTokenFilterPolicy` reset)
- Disable OpenSSH if not in use
- Block known brute-force IP ranges with explicit deny rules

### Service trim (reduces process count and idle CPU on Server 2025)
- Xbox services, DiagTrack telemetry, MapsBroker, Windows Search indexer
- Fax, PrintNotify, Tablet Input, biometric services
- Optional aggressive trim for telemetry workers and scheduled diagnostic tasks

### Defender tuning
- Path and process exclusions for your workload (configurable)
- Schedule full scans for off-hours
- Lower CPU priority during scans
- Disable archive/network-drive scanning (irrelevant on a VPS)
- Disable telemetry uploads (`MAPSReporting`, sample submission)

### Defense in depth
- Optional installation of [IPBan](https://github.com/DigitalRuby/IPBan) — auto-bans IPs after N failed authentication attempts
- Optional [Tailscale](https://tailscale.com/) install with `--unattended` flag (the configuration flag everyone forgets, leading to lockout after reboot)
- DNSSEC reminders if your domain registrar supports it

---

## Quick install

On the fresh Windows Server VPS, in an **elevated PowerShell** session:

```powershell
# Download and run
iwr -useb https://raw.githubusercontent.com/kastlevps/bastion-script/main/harden.ps1 | iex
```

Or download the script first, review it, then run it (recommended on a server you care about):

```powershell
iwr -useb https://raw.githubusercontent.com/kastlevps/bastion-script/main/harden.ps1 -OutFile harden.ps1
notepad harden.ps1   # review it
.\harden.ps1
```

The script is **interactive by design** — it asks for your public IP, the new admin username, and confirmation before each destructive section.

---

## What the script asks you for

| Prompt | Example | Why |
|---|---|---|
| Your public IP | `203.0.113.45` | RDP allow-list. Auto-detected via `ifconfig.me` if you press Enter |
| New admin username | `myadmin` | Avoid using `Administrator` (most-attacked username globally) |
| New admin password | (hidden) | 14+ chars enforced. Save it in a password manager BEFORE pasting |
| New RDP port | `47823` | Random unprivileged port. Default suggested if you press Enter |
| Workload type | `trading` / `web` / `general` | Tunes Defender exclusions and disabled services |

---

## The lessons (a.k.a. the Safety Net Pattern)

The script encodes lessons learned the hard way. The biggest one:

> **Never disable a working access path until the replacement has survived a real reboot test.**

Specifically:
1. **Add the new firewall rule first**, then narrow the existing one — never replace atomically.
2. **Test login as the new admin** before disabling `Administrator`.
3. **Verify Tailscale auto-reconnects after reboot** (`tailscale up --unattended` is the missing piece) before removing public RDP.
4. **Always keep at least one non-VPN access path** (public IP allow-list) as a fallback — VNC alone is not enough because cloud-provider VNC sessions time out and credentials regenerate per session.
5. **Service startup type matters**: `TermService` defaults to `Manual` on some Windows builds, which means RDP doesn't auto-start after reboot. Force it to `Automatic`.

These lessons came from a 4-hour lockout incident during the original hardening work. The script gates every destructive change on a verification step so you can't repeat them.

---

## What the script does NOT do

By design, this is a **bootstrap hardening script**, not a continuous monitoring solution. It runs once and exits. After it runs, you should:

- Snapshot the VPS via your provider (Contabo, Hetzner, AWS, etc.) as your "clean baseline"
- Set up your actual workload (web app, trading platform, game server, etc.)
- Snapshot again as "ready to deploy"
- Periodically review failed logon counts in Event Viewer (or use the included `health-check.ps1`)

For continuous audits, real-time alerts, weekly reports, and provider-integrated snapshot management, see **[KastleVPS](https://kastlevps.com)** (which I'm building based on what this script taught me).

---

## FAQ

### Is this safe to run on a server with my workload already installed?

Yes — but **take a snapshot first**. The script is non-destructive of user data; it only changes service states, firewall rules, and account configurations. But any sufficiently complex hardening can have unintended consequences. Snapshot first.

### Will this break my [trading platform / game server / web app]?

The Defender exclusions are configurable. The script will show you what it's about to add and ask for confirmation. Most trading platforms (MT4/MT5, NinjaTrader, cTrader) and common web stacks are pre-recognized.

### Does it work on Windows 10/11 desktop?

Mostly — it's tuned for **Server** SKUs, but the security parts (RDP hardening, firewall lockdown, Defender tuning) work fine on desktop Windows. Some service-trim items don't exist on desktop and will be silently skipped.

### What if I get locked out anyway?

The script always preserves at least one access path (public IP allow-list). Even if Tailscale fails, you can RDP from your home IP. If everything fails, your cloud provider's VNC console (Contabo, Hetzner, AWS Console Connect, etc.) bypasses the firewall completely. See the recovery notes at the end of the script's output.

### Is the script signed?

Not yet. Code signing requires a Microsoft Authenticode certificate ($300+/year). For now, the script is plain text — review it yourself before running. PRs welcome.

### Why PowerShell 5.1 syntax?

So it works on every Windows Server release from 2016 onward without requiring users to install PowerShell 7. Server 2025's built-in PowerShell can run this without modification.

---

## Want it automated?

This script is a one-shot, interactive hardening tool. If you want:

- Continuous monitoring of failed logons and account drift
- Weekly audit reports emailed to you
- Real-time alerts when a brute-force spike or new admin account appears
- Provider-integrated snapshots before each major change
- Workload-specific profiles (trading server, game server, etc.) with pre-tuned exclusions
- Recovery wizards for every major VPS provider (Contabo, Hetzner, AWS, etc.)

→ **[KastleVPS](https://kastlevps.com) is building exactly that.** Drop your email there to get notified at launch.

---

## Contributing

PRs welcome. Especially:

- Hardening checks for OS versions I haven't tested (Server Core, Nano Server, ARM64)
- Provider-specific cleanups (cloud-init accounts beyond `cloudbase-*`)
- Localization (the script currently assumes US-English locale strings)
- Translations of this README

Open an issue first for big changes so we can align on scope.

---

## License

MIT — do whatever you want with it. Attribution appreciated but not required.

If this saved you from a compromise, [tell me about it](mailto:hello@kastlevps.com). Stories help me make the script better.

---

## Acknowledgments

This script exists because:

- The bots at `3.65.40.162` and friends taught me to take RDP seriously
- The `TermService` running for 4 hours straight at 100% CPU got my attention
- A lockout incident during the rebuild taught me about the safety-net pattern
- [IPBan](https://github.com/DigitalRuby/IPBan) and [Tailscale](https://tailscale.com) do the heavy lifting at the edge

If you got hit by a similar attack and recovered, **share your story** — these accounts make the public hardening guides better for everyone.

