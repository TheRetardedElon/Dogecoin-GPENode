# Privacy Policy

**Project:** Dogecoin GPENode  
**Effective:** 2026-08-11  
**Canonical URL:** https://github.com/TheRetardedElon/Dogecoin-GPENode/blob/main/PRIVACY.md  

Related product (GUI / wallet): [Dogecoin Core Pro (Takeback) Privacy Policy](https://github.com/TheRetardedElon/Dogecoin-Takeback/blob/main/PRIVACY.md)

---

## Summary

Dogecoin GPENode is **operator software** that runs on **your** machine (or your servers). We do **not** run a user accounts system, analytics SDK, or ad network inside this repository’s binaries.

Most data GPENode handles **never leaves your computer** unless **you** configure outbound network features (Dogecoin P2P, optional CDN downloads, optional publish to a static host you control).

---

## Who we are

“We” / “GPE” refers to the maintainers of this open-source project (GitHub: [TheRetardedElon/Dogecoin-GPENode](https://github.com/TheRetardedElon/Dogecoin-GPENode)), including software and documentation published under this repository and related static package hosts such as `apt.dogecli.gopastearth.com` when used for distribution.

Contact for privacy questions: open an issue on this repository, or use the contact method listed on the GitHub organization / maintainer profile.

---

## What this software does with data

### Data that stays on your device

When you install and run GPENode, typical local data includes:

| Data | Where | Notes |
|------|--------|--------|
| Blockchain / UTXO / indexes | Your datadir (e.g. `%ProgramData%\DogecoinGPENode` or `/var/lib/dogecoin-gpenode`) | Required for a full or pruned node |
| `dogecoin.conf`, RPC credentials | Your datadir / config paths | Generated **per install**; do not share |
| Logs | Your datadir `logs/` or system journal | Debugging and operator history |
| Snapshots you create | Paths you choose | Only leave your machine if **you** publish them |

We do **not** receive copies of your `rpcpassword`, wallet files (if any), or chainstate through this software by default.

### Network activity (by design of a node)

A Dogecoin node **must** talk to the public peer-to-peer network to sync and stay online. That involves:

- Connecting to other Dogecoin peers (IPs, protocol messages, block/tx data)
- Optional RPC on addresses **you** configure (default in our packages: **localhost only**)

This is inherent to running a cryptocurrency node, not “telemetry” to GPE.

### Optional features that use the internet

| Feature | What may be transferred | Who receives it |
|---------|-------------------------|-----------------|
| **GitHub Releases / apt / downloads** | Your IP, User-Agent, which file you download | GitHub, your CDN/apt host (e.g. static apt origin), or other hosts you use |
| **Fast Sync / AssumeUTXO CDN** (if you enable fetch) | HTTPS requests for `latest.json` / snapshot `.dat` | The CDN host **you** configure (e.g. a public static host) |
| **Publish snapshots** (operator tools) | Files **you** choose to upload | The destination **you** set (`CDN_TARGET`, rsync, etc.) |
| **Updates / docs links** | Normal HTTPS if you open them | Destination site |

We do not use these channels to harvest wallet seeds or private keys.

### What we do **not** collect by default

- No mandatory cloud login  
- No advertising ID  
- No crash-reporting service bundled as a requirement of install  
- No selling of personal data as a product of this repository  

If a future optional component adds telemetry, it will be documented and default **off** where feasible.

---

## Websites and package mirrors

Static hosts used for distribution (examples):

- `https://github.com/TheRetardedElon/Dogecoin-GPENode` (source & releases)  
- `https://apt.dogecli.gopastearth.com/` (apt packages — static files only)  
- Optional UTXO CDN hosts (e.g. `sync.doge.gopastearth.com`) — **static files**, not an application API  

Those hosts may log standard web server data (IP, request path, time) for security and operations. They are not a Dogecoin RPC endpoint.

---

## Children

This software is intended for operators and developers. It is not directed at children under 13 (or the age required in your jurisdiction).

---

## Third parties

- **Dogecoin network peers** — independent operators; not controlled by us.  
- **GitHub / Microsoft** — if you use GitHub to clone or download (their privacy policy applies).  
- **Your OS / antivirus / package manager** — may scan installers (their policies apply).  
- **CDNs you configure** — under the operator of that host.

---

## Security of credentials

Installers may create a **unique** RPC password stored only on your machine (`RPC-CREDENTIALS.txt` / `dogecoin.conf`).  

- Keep those files private.  
- Do not commit them to git.  
- Prefer RPC bound to `127.0.0.1` unless you know you need otherwise.

See also [SECURITY.md](./SECURITY.md).

---

## Your choices

- Do not enable optional CDN fetch/publish if you do not want those transfers.  
- Uninstall the software and delete the datadir to remove local node data.  
- Firewall outbound P2P if you only want offline tools (node will not sync).  

---

## Changes

We may update this policy by editing this file in the repository. The **Effective** date at the top will change. Continued use of new releases after a material change constitutes acceptance where allowed by law.

---

## License vs privacy

Source code is offered under the repository [LICENSE](./LICENSE) (MIT). That license governs **copyright of the code**, not this privacy notice.
