# The koura box

One Hetzner CX23 (2 vCPU / 4 GB / 40 GB, ~€4.50/mo) at
`koura.codecanoe.com`, running three apps behind one nginx:

```
koura.codecanoe.com   ──┐
invoice.codecanoe.com ──┼── nginx (ACME/TLS) ──▶ 127.0.0.1:4000 / :4001 / :4002
kai.codecanoe.com     ──┘                          │
                                                   ├── postgresql (koura)
                                                   ├── typesense  (koura)
                                                   └── kai-scraper on :8787
```

The machine is `hosts/koura/configuration.nix`. The three apps' systemd units
are flake inputs from their own repos; their releases are not in this closure
at all — each ships into `/nix/var/nix/profiles/<app>` from its own repo with
`bin/deploy-app`. That split is the point: **a rebuild here never compiles an
app, and an app deploy never rebuilds the box.**

## Deploying a system change

```sh
./infra.sh deploy koura          # switch now, built on the box
./infra.sh deploy koura boot     # stage for next reboot
./infra.sh deploy koura test     # activate without persisting
```

Atomic, with automatic rollback if the new generation fails to boot
(`nixos-rebuild --rollback` on the box to go back by hand). Changing a secret
restarts only the units named in its `restartUnits`.

## First install

`./infra.sh setup koura` converts a stock Ubuntu VM to NixOS **in place** with
[`nixos-infect`](https://github.com/elitak/nixos-infect).

> **Why infect and not nixos-anywhere?** Hetzner's recent Ubuntu images boot
> UEFI with Secure Boot on, which blocks kexec of the unsigned NixOS installer
> (`PEFILE: Unsigned PE binary`). nixos-infect never kexecs — it replaces the
> OS on the running system and keeps the image's partition layout. Secure Boot
> must still be **off** for the infected system to boot; setup checks before
> touching anything.

```sh
sops .sops.env      # HCLOUD_TOKEN for the project the box lives in
./infra.sh setup koura
```

It creates the VM (matching a local `~/.ssh` key against the project by
fingerprint, uploading it if needed), infects, reboots into NixOS, copies the
generated `hosts/koura/hardware-configuration.nix` back into this repo,
installs the age key at `/var/lib/sops-nix/age/keys.txt` so the box can
decrypt `secrets/koura/*`, then builds and switches `.#koura` on the box.

Options are passed straight through to `bin/provision`, the Hetzner backend:
`--existing` adopts a server that already exists (re-running is always safe —
completed steps are skipped); `--primary-ipv4 <id-or-name>` attaches an
existing primary IP so DNS keeps pointing somewhere real. To free an old box's
IP first: `hcloud primary-ip update <id> --auto-delete=false`, delete the
server, then pass it here.

Afterwards **commit `hosts/koura/hardware-configuration.nix`** — flakes only
see git-tracked files, and the host will not build without it.

Then ship each app from its own repo: `bin/deploy-app`.

## DNS

octoDNS drives deSEC, and `dns/zones/codecanoe.com.yaml` is the source of
truth for the **whole zone** — not just this box.

```sh
bin/dns          # preview the diff
bin/dns --doit   # apply
```

Needs `DESEC_TOKEN` from `.sops.env`. Expect the diff to be exactly what you
changed: octoDNS treats the zone file as the entire zone, so a stray deletion
means a record (mail MX, another host) is missing from the file.

The ACME order for a new name fails until DNS resolves, but a systemd timer
retries, so order is not fatal — just slow.
`systemctl start acme-<domain>.service` forces a retry.

## Secrets

Encrypted in this repo, decrypted on the box at activation by
[sops-nix](https://github.com/Mic92/sops-nix), to `/run/secrets/*` on tmpfs.

| File | Read by |
| --- | --- |
| `secrets/koura/koura.env` | koura: `SECRET_KEY_BASE`, `TYPESENSE_API_KEY`, `BASIC_AUTH_*`, `RELEASE_COOKIE`, optional `RESEND_API_KEY` |
| `secrets/koura/typesense-api-key` | Typesense's own `apiKeyFile` — **must hold the same value** as `TYPESENSE_API_KEY` |
| `secrets/koura/invoice-sync.env` | invoice_sync: its `SECRET_KEY_BASE`, basic-auth pair and API credentials |
| `secrets/koura/kai.env` | kai: `SECRET_KEY_BASE`, basic-auth pair, the Delhaize account its delivery step signs in with |

Edit with `sops secrets/koura/koura.env`, commit, deploy. `.sops.yaml`
re-encrypts to the right recipient; sops-nix restarts the affected units.

The box holds the same age identity used for the dev shell, at
`/var/lib/sops-nix/age/keys.txt` (0400), put there at setup. Nothing
about a secret is box-specific, so a reprovision needs no re-encryption.

**Basic auth is not optional in practice.** Neither kai nor invoice_sync has a
login of its own, and both hold real data — kai's database stores a Paprika
account password. With `BASIC_AUTH_USERNAME`/`BASIC_AUTH_PASSWORD` unset the
plug is a no-op and the site is simply open.

## Memory

4 GB, and it is the real constraint. Typesense loads a ~500 MB embedding
model; kai's sidecar drives headless Firefox at ~650 MB warm. `zramSwap` is on,
the sidecar is capped (`MemoryHigh=900M`, `MemoryMax=1400M`) and closes an idle
browser after ten minutes. Two browsers at once measured ~1.3 GB against ~1.2 GB
spare and put the box into permanent reclaim, which is why kai shares one
browser between both shops. If it starts thrashing again, kai's sidecar is the
piece to move to its own machine — nothing but `SCRAPER_URL` points at it.

## Backups

`services.postgresqlBackup` writes a nightly `pg_dump` to
`/var/backup/postgresql/`. Typesense is rebuildable from Postgres and is not
backed up. kai's SQLite database is **not** backed up yet. Worth syncing
`/var/backup/postgresql/` off-box (restic to a Storage Box, or a cron `scp`).

## Things that have gone wrong

From the first provision (July 2026), now handled by `bin/provision`'s
`infect-extras.nix` — kept here in case infect or nixpkgs shift again:

- **Box boots but is unreachable, Ubuntu units in the journal** — the
  systemd-based initrd (default on nixos-unstable since ~2026) skips
  nixos-infect's `NIXOS_LUSTRATE` first-boot step, so Ubuntu's `/etc` never
  moves to `/old-root` and activation cannot take over. Fix: scripted initrd
  for the bootstrap system (`boot.initrd.systemd.enable = false`).
- **Box boots, sshd runs, but no IPv4** — infect declares `defaultGateway`
  without an interface; that variant is applied by `network-setup.service`,
  which does not run. Interface-scoped gateways work. Hetzner's v4 gateway is
  always `172.31.1.1`. IPv6 has the same shape and always worked, which is a
  handy back door: `ssh root@<v6-addr>`, then
  `ip route add default via 172.31.1.1 dev eth0 onlink`.
- **`typesense: API key is not specified`** — the unit runs as a `DynamicUser`
  and cannot own the key file. The secret is group-readable
  (`group = "typesense-secrets"`, `mode = "0440"`) and the unit joins that
  static supplementary group in the host config.
- **`koura.service: cat: releases/COOKIE: No such file`** — nixpkgs'
  `mixRelease` strips the cookie file; `RELEASE_COOKIE` is set in koura's own
  service module (the value is irrelevant, distribution is off).
- **`migrate: permission denied to create extension "vector"`** — handled by
  the `koura-db-extensions` oneshot, which pre-creates it as superuser.

## Aligning pins

`nixpkgs` and `sops-nix` are pinned in `flake.lock` to what the box runs.
Updating them rebuilds the machine, so do it deliberately:

```sh
nix flake update nixpkgs sops-nix
./infra.sh deploy koura boot   # stage it, reboot when you are watching
```

An out-of-step `sops-nix` fails at *evaluation*, not at runtime — the giveaway
is `sops-install-secrets` asking for a `buildGoNNNModule` that its nixpkgs no
longer has.
