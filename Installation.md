# Installing LibreLane

Verified working with LibreLane v3.0.10 (`bf8cc13`) on Ubuntu, PDK `sky130A`.

## 0. How LibreLane is installed

LibreLane is **not** a pip package and **not** an apt package — it's distributed
as a **Nix environment**. This explains most first-time confusion:

- There's no `librelane` binary on your normal `PATH`.
- `pip list | grep librelane` shows nothing.
- `which librelane` returns nothing.
- **None of that means it's missing.**

Installing means installing Nix, then cloning the repo. Nix pulls the entire EDA
toolchain — Yosys, OpenROAD, Magic, KLayout, Netgen, Verilator — as pre-built
binaries pinned to versions known to work together. Everyone running LibreLane
runs bit-identical tools.

You enter the environment with:

```bash
cd ~/librelane
nix-shell
```

Your prompt changes. Inside that shell `librelane` exists. Outside it, it does not.

## 1. Requirements

**Official minimums:** quad-core CPU @ 2.0 GHz+, 8 GiB RAM, Ubuntu 22.04+
(other distros work; Ubuntu is what upstream tests).

**Recommended:** 6th-gen Intel Core / AMD Ryzen 1000-series or later, 16 GiB RAM.

**Disk — budget ~20 GB:**

| Path | Size | What it is |
|---|---|---|
| `/nix/store` | ~13 GB | EDA toolchain + dependencies |
| `~/.volare` | ~2 GB | PDK (e.g. sky130A) |
| `~/librelane` | ~50 MB | The repo itself |

**Network:** install downloads ~5–6 GB. A stable connection matters more than a
fast one (see §3.3).

## 2. Install Nix

### 2.1 Don't use apt

```bash
# ✗ do not do this
sudo apt install nix
```

The apt version is severely out of date and fails in hard-to-diagnose ways.

### 2.2 Install with the official installer

```bash
sudo apt-get install -y curl

curl --proto '=https' --tlsv1.2 -fsSL https://artifacts.nixos.org/nix-installer | sh -s -- install --no-confirm --extra-conf "
    extra-substituters = https://nix-cache.fossi-foundation.org
    extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
    extra-experimental-features = nix-command flakes
"
```

The `--extra-conf` block wires in LibreLane's binary cache at install time — the
difference between a 10-minute install and a multi-hour source build.

**Then close every open terminal** — the installer edits your shell profile and
existing shells won't see the change. Verify in a fresh terminal:

```bash
nix --version
```

### 2.3 If you already have Nix installed

Add the cache manually. Where depends on which Nix you have:

```bash
nix --version
```

- **"Determinate Nix"** → edit `/etc/nix/nix.custom.conf` (Determinate Nix
  regenerates `/etc/nix/nix.conf` and overwrites anything put there directly).
- **Plain upstream Nix** → edit `/etc/nix/nix.conf`.

```ini
extra-substituters = https://nix-cache.fossi-foundation.org
extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
extra-experimental-features = nix-command flakes
```

Then restart the daemon:

```bash
sudo systemctl restart nix-daemon
# or: sudo pkill nix-daemon
```

**Three traps to avoid:**

1. **Duplicate keys override, not append.** A second `extra-substituters` line
   silently replaces the first — combine multiple caches on one space-separated
   line: `extra-substituters = https://cache-one https://nix-cache.fossi-foundation.org`.
2. **You probably can't do this as a normal user.** Check
   `nix config show | grep trusted-users`. If it shows only `root`, edits via
   `~/.config/nix/nix.conf` or `--option` on the command line are silently
   ignored — the system file must be edited as root.
3. **Remove dead substituters.** A stale cache entry (e.g. the old
   `openlane.cachix.org`) adds a timeout to every lookup since Nix queries every
   substituter for every store path.

### 2.4 Verify the cache before anything long

Takes seconds, saves hours:

```bash
cd ~/librelane
nix-build shell.nix --dry-run
```

- **Mostly "will be fetched"** → cache is working, proceed.
- **Hundreds of "will be built"** → cache isn't reachable. Stop, revisit §2.3 —
  otherwise you're compiling OpenROAD and friends from source (hours, possibly
  exhausting your RAM).
- **Almost nothing listed** → already in `/nix/store`. Also a pass.

## 3. Install LibreLane

### 3.1 Clone

```bash
git clone https://github.com/librelane/librelane
cd librelane
```

That's the whole install step — no build, no `make`, no `pip install`. To pin a
release instead of tracking `main`:

```bash
git checkout 3.0.10
```

### 3.2 Enter the environment

```bash
nix-shell
```

First run takes ~10 minutes while several GB stream from the cache. Subsequent
entries are near-instant.

### 3.3 If the download fails partway with DNS errors

Symptom:

```
error: unable to download 'https://cache.nixos.org/...':
       Could not resolve host: cache.nixos.org
```

**Cause:** Nix opens 25 parallel connections by default — many consumer router
DNS resolvers collapse under that burst.

**Fix** — throttle Nix (same conf file as §2.3):

```ini
http-connections = 10
download-attempts = 7
```

If it persists, consider switching to a public DNS resolver (e.g. Cloudflare
`1.1.1.1`).

## 4. Sanity check

```bash
librelane --smoke-test
```

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `librelane: command not found` | Not in the Nix shell | `cd ~/librelane && nix-shell` |
| Nix wants to build hundreds of paths | Cache not configured/trusted | §2.3 + §2.4 |
| `Could not resolve host` during download | 25 parallel connections overwhelming DNS | §3.3 |
| Cache line added but ignored | Duplicate key, or `trusted-users = root` only | §2.3 |
| Settings vanish after a Nix update | Determinate Nix regenerates `nix.conf` | Use `nix.custom.conf` |
| First run seems hung | Downloading the PDK | Let it finish, watch `~/.volare` grow |

## 6. Reinstalling, updating, removing

```bash
# update
cd ~/librelane && git pull && nix-shell

# reclaim disk space
nix-collect-garbage -d

# remove entirely
rm -rf ~/librelane ~/.volare
nix-collect-garbage -d
```

## Further reading

- Repo: <https://github.com/librelane/librelane>
- Local docs: `~/librelane/docs/source/`
- Newcomers tutorial: `~/librelane/docs/source/getting_started/newcomers/index.md`
- Nix EDA cache setup: <https://github.com/fossi-foundation/nix-eda/blob/main/docs/installation.md>
