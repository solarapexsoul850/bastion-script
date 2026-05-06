# Forum posts — drafts and strategy

These are first-draft posts for validating KastleVPS demand by sharing the bastion-script story and asking for feedback. **Do not post all at once** — start with one community, learn what resonates, then adapt the others.

---

## Strategy

### Goal of these posts (in priority order)

1. **Validate demand** — Are real users genuinely getting hit? Would they pay for an automated solution?
2. **Build trust** — Demonstrate you've actually done the work (the GitHub repo proves it)
3. **Drive warm leads** — README mentions kastlevps.com → email capture → launch list
4. **Get feedback** — Comments will reveal what's missing, what to prioritize for v1

### Posting order (do not skip)

1. **r/sysadmin first** — most critical audience. If they accept it, you've passed the rigor test.
2. **r/algotrading + MQL5 forum** — your actual target buyer (traders running MT5 on VPS)
3. **r/HomeLab + r/selfhosted** — adjacent audience, broader VPS interest
4. **r/Forex + BabyPips** — softer audience, more focused on trading than security
5. **Hacker News** — only AFTER you have positive engagement on Reddit. HN is brutal on weak posts.

### Rules of engagement

- **Don't pitch the SaaS in the post body.** The link in the GitHub README does the conversion.
- **Don't link kastlevps.com directly** in your forum post. The mods often flag it as self-promotion.
- **Engage with every comment for the first 48 hours.** Subreddit algorithms reward responsive OPs.
- **Share it on Tuesday-Thursday morning** (US/EU peak hours). Avoid weekends and Mondays.
- **One subreddit per day.** Posting the same thing across 5 subs simultaneously gets you flagged as a spammer.

### What to track

- Click-throughs to GitHub repo (GitHub Insights → Traffic → Referring sites)
- Stars on the repo (don't beg for stars, but watch the count)
- Email signups via `hello@kastlevps.com` (organic sign of demand)
- Comment patterns: are people asking "how do I get this for X?" → tells you what to build

---

## Post #1 — r/sysadmin

**Best for:** technical credibility, broad audience, gateway to other communities.

**Title:**
```
Got my Windows Server VPS brute-forced 3 hours after launch — wrote up the script + lessons
```

**Body:**
```
Newbie cloud-VPS mistake on my part — bought a Contabo Windows Server 2025 box for an
automated trading project, pointed RDP straight at the public internet because "I'll harden
it later this week." Within 3 hours of going online, the bots found it.

What I noticed first wasn't the failed logins — it was CPU pegged at 50%+ on a server doing
basically nothing. I assumed it was my workload misbehaving. It wasn't. It was TermService
(the RDP service) running at 100% of one core, just handling brute-force authentication
attempts. By the time I checked Event Viewer, I had 400+ failed logins in the last hour from
notorious source IPs (3.65.40.162, 45.133.195.x, 181.215.65.x range).

By the time I noticed, an attacker had an established TCP connection on 3389. I didn't wait
to see if they got in — I closed it off, audited the box, and decided to nuke and rebuild.
You can never really prove a Windows box is clean once attackers had an established session.

The rebuild itself taught me more than the original compromise. I locked myself out twice
during hardening:

1. Disabled public RDP before verifying Tailscale auto-reconnects after reboot. Turns out
   `tailscale up` doesn't survive a reboot unless you use `--unattended`. After my reboot,
   Tailscale's service was running but unauthenticated, so the VPS was unreachable on both
   public RDP (firewall closed) AND Tailscale (not authenticated). Had to recover via VNC.

2. Set TermService to default startup type, which is Manual on some Windows builds. Service
   didn't auto-start after reboot, RDP wasn't listening on the new port, and again VNC to
   the rescue.

Both lockouts followed the same pattern: I disabled a working access path before verifying
the replacement survived a reboot. Should have done the verification first. I now call this
the "safety net pattern" — never replace, always add-then-narrow.

Wrote up the script + the safety pattern here:
https://github.com/kastlevps/bastion-script

It does the usual stuff (RDP port migration, IP allow-listing, Defender exclusions, IPBan,
service trim) but with the safety net pattern enforced — every potentially-locking change
verified before the previous access path is removed.

Genuinely curious — has this happened to anyone else here? What did you do?

Specifically interested in:
- How long did your manual hardening take, end to end?
- Did you build something automated for it, or just have a runbook?
- Any horror stories where the hardening itself caused the lockout?
```

**Where:** https://www.reddit.com/r/sysadmin/

**Best time:** Tuesday or Wednesday, 9-11 AM US Eastern.

---

## Post #2 — r/algotrading

**Best for:** your actual target buyer (traders running MT4/MT5 on VPS).

**Title:**
```
PSA for anyone running MT5 on a VPS — got brute-forced 3 hours after launch, here's the
hardening script
```

**Body:**
```
Brief PSA in case anyone here is doing what I was doing — running MT5 EAs (forex/gold) on a
Contabo VPS with default Windows Server settings. Within 3 hours of launching the box, RDP
was being brute-forced by botnets at 400+ login attempts per hour. CPU pegged at 50%+ JUST
from the auth attempts (not even my EAs running).

I thought my Quantum Queen + Forex Fury setup was misbehaving. It wasn't. The TermService
process was burning 2,400+ CPU seconds handling botnets trying every common password.

If your MT5 is on a VPS and you didn't explicitly harden it, check your Event Viewer right
now: `Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} | Measure-Object`

If that number is in the hundreds (or thousands), you're being brute-forced too. Eventually
one weak password gets through, and then you've got an attacker watching your trades.

I rebuilt the box from scratch and wrote up everything I did into a hardening script. Free
on GitHub, MIT license, no signup:

https://github.com/kastlevps/bastion-script

Specifically tuned for traders — Defender exclusions for MT4/MT5/NinjaTrader so it doesn't
slow your tick processing. Trading server profile picks up automatically.

Curious if anyone else here has been hit by this? Especially interested in:

- Did you notice from the CPU usage like I did, or did your EAs stop working first?
- For those running 5+ pairs across multiple MT5 instances — how do you handle the broker
  spread / DDoS sensitivity?
- Anyone using prop firm VPS that came pre-hardened? Or do those have similar issues?
```

**Where:** https://www.reddit.com/r/algotrading/

**Best time:** Tuesday/Wednesday morning. Algo traders are checking subs around market open.

---

## Post #3 — MQL5 forum

**Best for:** highest concentration of MT5 users specifically. Smaller community, more direct conversion.

**Title:**
```
Lessons from getting brute-forced on a Windows VPS running MT5 — open-source hardening script
```

**Body:**
```
Hi all — sharing this in case it saves anyone the headache I went through last week.

I bought a Contabo Windows VPS for running 3 MT5 instances (Coinexx — forex, gold, BTC).
Standard setup, RDP exposed on default port 3389 because the broker's MT5 setup guide didn't
mention hardening. Within hours of going online, the box was being brute-forced.

What gave it away wasn't the failed-login emails (there weren't any) — it was CPU at 50%+
on a box that should have been mostly idle (just MT5 running). Looked at Task Manager:
TermService (the RDP service itself) was burning 100% of one core, handling thousands of
authentication attempts per minute from attacker IPs.

By the time I checked the Security event log, there were 400+ failed login attempts in just
the last hour — from well-known botnet ranges (181.215.65.x, 45.133.195.x, etc.).

I rebuilt the VPS and wrote up everything I did. Sharing it here because I don't think this
is a niche problem — anyone who buys a default Windows Server VPS for MT5 has this exposure
within the first day:

https://github.com/kastlevps/bastion-script

The script is tuned for trading specifically — adds Defender exclusions for `terminal64.exe`
and the MetaQuotes appdata folders, so antivirus scanning doesn't slow your tick processing.
Also handles the multi-instance MT5 setup (separate `C:\MT5\<broker>` folders with
`/portable` shortcuts).

Three things I'd love feedback on:

1. **Has this happened to you?** I'd be surprised if I'm the only one. If you got hit, how
   did you find out?
2. **Brokers with built-in VPS** (FX hosting, ForexVPS, etc.) — are those pre-hardened, or
   do they ship with the same defaults?
3. **Anyone running MT5 on Linux + Wine** to avoid the Windows attack surface entirely?

Thanks!
```

**Where:** https://www.mql5.com/en/forum (start in "Trading Systems" or "Experts" section)

**Best time:** Weekdays, late morning UTC (covers Asian trading session ending + European open).

---

## Post #4 — r/HomeLab (general VPS audience)

**Title:**
```
Wrote up an open-source Windows Server VPS hardening script after getting brute-forced 3
hours after launch
```

**Body:** Same as r/sysadmin post but slightly less technical, more "story" framing.

---

## Post #5 — Hacker News (Show HN)

**Only attempt this AFTER 2-3 successful Reddit posts** — HN is brutal on poorly-positioned posts.

**Title:**
```
Show HN: Bastion-script — battle-tested Windows Server VPS hardening script
```

**Body:**
```
Wrote this after getting my Contabo Windows VPS brute-forced 3 hours after launch.
TermService at 100% CPU, 400+ failed RDP logins in an hour from known botnet IPs. Rebuilt
the box, hardened it properly, and wrote up the steps as a single PowerShell script.

The interesting bit isn't the hardening itself — that's well-documented in MS guides — but
the safety net pattern that prevents you from locking yourself out during hardening. I
locked myself out twice (Tailscale didn't auto-reconnect after reboot because I forgot
`--unattended`; TermService didn't auto-start because of default Manual startup type), and
both times the failure followed the same pattern: I disabled a working access path before
verifying its replacement survived a reboot.

The script encodes that pattern: every potentially-locking change verifies the replacement
first, and reboots are gated on dual-path access checks.

Tested on Server 2016/2019/2022/2025. MIT license. Single file, no dependencies.

[Github link]

Feedback welcome — especially edge cases I haven't tested (Server Core, Nano Server, ARM64).
```

**Where:** https://news.ycombinator.com/submit

**Best time:** Tuesday-Thursday, 8-10 AM US Pacific.

---

## After the posts

### What "validation" looks like

| Signal | What it means |
|---|---|
| 5+ replies saying "this happened to me" | Real demand, build the SaaS |
| 100+ GitHub stars in first week | Strong organic interest, accelerate launch |
| 5+ emails to hello@kastlevps.com | Warm leads from the README link |
| Replies asking "what about Linux/Mac/X provider?" | Roadmap signal, not v1 priority |
| Crickets / a few upvotes, no comments | Reposition the message OR pick a different community |

### When to stop and pivot

If three posts in three different communities get crickets, the message is wrong, not the
audience. Reposition before posting #4.

### When to accelerate

If r/sysadmin or r/algotrading has 200+ upvotes and 50+ comments within 48 hours, you have a
launch — start building the agent immediately and offer early access in the comments.

---

## Templates for the engagement comments

**Common comment**: "Have you tried fail2ban / IPBan / Tailscale?"

**Reply template:**
```
Yep — IPBan is in the script as the dynamic-block layer (handles the long-tail attackers
not in the static blocklist). Tailscale is the recommended primary access path with the
public IP allow-list as a fallback. The script's `Install-Tailscale` function specifically
warns about the `--unattended` flag because that's exactly what bit me on the first reboot.
```

**Common comment**: "Why Windows? Just use Linux."

**Reply template:**
```
For my use case (algorithmic trading via MT5), Windows is the only platform that runs the
broker's official client. Linux + Wine works for some EAs but breaks on others. So Windows
hardening is the actual requirement, not a choice.

But also — even if your workload could run on Linux, the same brute-force pattern hits SSH.
The script's safety-net pattern translates directly to SSH hardening; the lockout mechanics
are identical.
```

**Common comment**: "What about Cloudflare Tunnel / WireGuard / SSH bastion?"

**Reply template:**
```
All valid — and any private overlay works (Tailscale is just my pick because it's free for
personal use and `--unattended` mode handles the auto-reconnect). The key insight is the
SAFETY NET, not the specific tool. Whatever you use, verify it auto-reconnects through a
reboot before you disable the public path.
```

---

## Personalization checklist before posting

- [ ] Replace `Quantum Queen + Forex Fury` with your actual EAs (or remove if private)
- [ ] Replace `Coinexx` with your actual broker (or "my forex broker")
- [ ] Verify the GitHub URL is the correct kastlevps account URL
- [ ] Soften specific IPs if you don't want to single them out (the 181.215.65.x range is fair game — it's a known botnet)
- [ ] Read the body OUT LOUD before posting — does it sound like a person, or like marketing copy?
- [ ] If marketing copy, rewrite. Reddit algorithms detect formality and downvote.

---

## Final reminder

The posts above are first drafts — your voice matters. Edit until they sound like you, not
me. Reddit users have a sensitive bullshit detector for AI-written posts — keep contractions,
keep informal phrasing, keep the human edges in.

Don't try to be perfect. Authenticity beats polish.
