# infra

Every machine that is not ephemeral, declared in one place: the rented box,
the Pi, and the VM used to test changes before they touch either.

## The machines

| Host | What it is | Deploy |
| --- | --- | --- |
| `koura` | Hetzner CX23 at `koura.codecanoe.com`. Runs three apps behind one nginx: koura, invoice_sync and kai. | `./deploy.sh koura` |
| `rabbit` | A local NixOS VM for trying a config out before it goes anywhere real. | `./deploy.sh rabbit`, or `nix build .#rabbit-vm` |
| `mole` | Raspberry Pi 5. **Not NixOS** — Raspberry Pi OS with Nix on top, so it takes a package list rather than a system closure. | `hosts/mole/deploy-pi.sh` |

## Who owns what

An app repo owns the app. This repo owns the machine it lands on. The line
between them is a NixOS module:

```
infra                     the box: nginx, TLS, Postgres, Typesense, the
                          firewall, every app's sops secret, DNS
  └── flake input ───▶    koura, invoice_sync, kai
                          each exporting nixosModules.<app>: its systemd
                          units, and nothing about any host
```

Releases never travel this way. Each app ships its own build into its own Nix
profile (`bin/deploy-app` in that repo) and the unit resolves the running
version through the profile. So a rebuild here never compiles an app, an app
deploy never rebuilds a host, and the two can happen in either order.

Adding a fourth app to a box is: export `nixosModules.<app>` from its repo,
add it as an input here, give it a vhost and a secret in the host's
`configuration.nix`.

## Layout

```
flake.nix              hosts + the dev shell
deploy.sh <host>       nixos-rebuild switch, built on the target
hosts/koura/           the box: configuration.nix + hardware-configuration.nix
hosts/rabbit/          the test VM
hosts/mole/            the Pi (package list + its own deploy script)
modules/               base, users, wireguard, trusted-keys — shared by hosts
secrets/koura/         sops blobs the box decrypts at activation
secrets/secrets.yaml   wireguard keys for rabbit
dns/                   octoDNS: the whole codecanoe.com zone
bin/dns                preview / apply DNS
bin/provision          create the Hetzner VM and convert it to NixOS
nix/                   packages missing from nixpkgs (octoDNS's deSEC provider)
```

## Before the first use

The dev shell decrypts `.sops.env` on entry, and that file does not exist yet.
It needs two tokens:

```sh
sops .sops.env
```

```
DESEC_TOKEN=...     # deSEC API token — bin/dns
HCLOUD_TOKEN=...    # Hetzner Cloud, the project the box lives in — bin/provision
```

Both were previously in the koura repo's `.sops.env`, which is where to copy
them from. Everything else — the encrypted host secrets in `secrets/` — is
already here and already encrypted to the age key this machine holds.

## Deploying

```sh
./deploy.sh koura           # switch now
./deploy.sh koura boot      # stage for next reboot (the safe one)
./deploy.sh koura test      # activate without persisting
```

Builds on the target: its uplink beats pushing a closure from a home
connection. See [DEPLOY.md](DEPLOY.md) for the box in detail — provisioning,
secrets, DNS and what has gone wrong before.
