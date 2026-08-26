#!/usr/bin/env bash
# infra — one entry point for every machine declared in this repo.
#
#   ./infra.sh setup  <host> [options]   bring a machine into existence
#   ./infra.sh deploy <host> [mode]      rebuild a machine that already exists
#   ./infra.sh dns    [--doit]           preview / apply DNS for codecanoe.com
#   ./infra.sh hosts                     what is declared here
#
# `setup` is the from-nothing path, and it is genuinely different per machine:
# a rented VM has to be created and converted in place, a VM on a hypervisor is
# installed over the network onto a wiped disk, and the Pi is not NixOS at all.
# Which path a host takes is its `kind` in the table below; the work itself
# lives in bin/ or hosts/<host>/. All of them are re-runnable — a step that is
# already done is skipped, so a partial failure is fixed by running it again.
#
# `deploy` is the everyday one, and it is the same everywhere: build on the
# target, activate there. It never ships an app — each app deploys its own
# release into its own Nix profile from its own repo (`bin/deploy-app` there).
set -euo pipefail
cd "$(dirname "$0")"

# --- The machines -----------------------------------------------------------
#
# kind decides how `setup` and `deploy` treat a host:
#
#   hetzner         a cloud VM: created with hcloud, converted from the stock
#                   Ubuntu image to NixOS in place with nixos-infect
#   nixos-anywhere  an already-reachable machine, installed onto a disko layout
#                   over SSH — wipes the disk
#   nix-on-os       not NixOS: someone else's distro with Nix on top, so it
#                   takes a package profile rather than a system closure

HOSTS="koura rabbit mole"

host_spec() {
  case "$1" in
    koura)
      ADDRESS="koura.codecanoe.com"   # by name: that is what its host key is known under
      KIND="hetzner"
      ABOUT="Hetzner CX23 — koura, invoice_sync and kai behind one nginx"
      ;;
    rabbit)
      ADDRESS="91.98.95.99"
      KIND="nixos-anywhere"
      ABOUT="NixOS VM for trying a config out before it touches anything real"
      ;;
    mole)
      ADDRESS="klaus@192.168.1.219"
      KIND="nix-on-os"
      ABOUT="Raspberry Pi 5 — Raspberry Pi OS with Nix on top"
      ;;
    *)
      echo "Unknown host: $1" >&2
      echo "Declared here: $HOSTS" >&2
      exit 1
      ;;
  esac
}

log()  { echo "[infra] $*"; }
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

# --- setup ------------------------------------------------------------------

cmd_setup() {
  [ $# -ge 1 ] || { echo "Usage: ./infra.sh setup <host> [options]" >&2; exit 1; }
  local host="$1"; shift
  host_spec "$host"

  [ -d "hosts/$host" ] || { echo "hosts/$host does not exist — declare the machine first" >&2; exit 1; }

  case "$KIND" in
    hetzner)        exec bin/provision "$host" "$@" ;;
    nixos-anywhere) setup_nixos_anywhere "$host" "$@" ;;
    nix-on-os)      exec "hosts/$host/setup-pi.sh" "$ADDRESS" "$@" ;;
  esac
}

# Install NixOS onto a machine we can already SSH into. nixos-anywhere
# partitions from hosts/<host>/disk.nix, so it destroys whatever is on it.
setup_nixos_anywhere() {
  local host="$1"
  local target="root@$ADDRESS"

  echo "This wipes $ADDRESS ($ABOUT) and installs NixOS from .#$host."
  read -r -p "Type 'yes' to continue: " confirm
  [ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

  log "Installing over SSH (this reboots the machine when it finishes)..."
  nix run github:nix-community/nixos-anywhere -- --flake ".#$host" "$target"

  log "Waiting for it to come back..."
  local i
  for i in $(seq 1 60); do
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR "$target" nixos-version >/dev/null 2>&1 && break
    [ "$i" -eq 60 ] && { echo "Not reachable after 5 minutes." >&2; exit 1; }
    sleep 5
  done

  check_host_age_key "$host" "$target"
  log "Deploying .#$host..."
  cmd_deploy "$host"
}

# Unlike the rented box — which holds the admin age key outright — a machine
# installed this way decrypts with its own SSH host key (see
# `sops.age.sshKeyPaths` in its configuration.nix). A reinstall regenerates
# that key, so .sops.yaml has to learn the new one and the secrets have to be
# re-encrypted to it. Reporting rather than rewriting: editing the recipient
# list of an encrypted store is not something to do behind someone's back.
check_host_age_key() {
  local host="$1" target="$2" age_key
  age_key=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
              "$target" "cat /etc/ssh/ssh_host_ed25519_key.pub" |
            nix shell nixpkgs#ssh-to-age -c ssh-to-age) || return 0

  if grep -q "$age_key" .sops.yaml; then
    log "Host key already a sops recipient — secrets will decrypt."
    return 0
  fi

  cat <<KEY

  ! $host's host key is not in .sops.yaml, so it cannot decrypt its secrets.
    Add it under keys: and to the creation_rule that covers them —

      - &${host}_host $age_key

    then re-encrypt what it reads:  sops updatekeys secrets/secrets.yaml
    and deploy again:               ./infra.sh deploy $host

KEY
}

# --- deploy -----------------------------------------------------------------

cmd_deploy() {
  [ $# -ge 1 ] || { echo "Usage: ./infra.sh deploy <host> [switch|boot|test]" >&2; exit 1; }
  local host="$1" mode="${2:-switch}"
  host_spec "$host"

  if [ "$KIND" = "nix-on-os" ]; then
    # No system closure to switch to — just the shared package profile.
    exec "hosts/$host/deploy-pi.sh" "$ADDRESS"
  fi

  case "$mode" in
    switch|boot|test) ;;
    *) echo "Invalid mode '$mode' — use switch, boot or test" >&2; exit 1 ;;
  esac

  # Building on the target beats pushing a closure from a home connection.
  # Unless we *are* the target, in which case there is nothing to push.
  local -a where=(--target-host "root@$ADDRESS" --build-host "root@$ADDRESS")
  local sudo=""
  if [ "$(hostname)" = "$host" ]; then
    log "Running on $host itself — deploying locally."
    where=()
    sudo="sudo"
  fi

  log "nixos-rebuild $mode .#$host"
  $sudo nixos-rebuild "$mode" --flake ".#$host" "${where[@]}"

  case "$mode" in
    switch) log "Active now." ;;
    boot)   log "Staged. Reboot to activate; if SSH then fails, roll back from the rescue console." ;;
    test)   log "Active, but not persisted — a reboot reverts it." ;;
  esac
}

# --- the rest ---------------------------------------------------------------

cmd_dns() { exec bin/dns "$@"; }

cmd_hosts() {
  local host
  for host in $HOSTS; do
    host_spec "$host"
    printf '  %-8s %-14s %-22s %s\n' "$host" "$KIND" "$ADDRESS" "$ABOUT"
  done
}

case "${1:-help}" in
  setup)  shift; cmd_setup "$@" ;;
  deploy) shift; cmd_deploy "$@" ;;
  dns)    shift; cmd_dns "$@" ;;
  hosts)  cmd_hosts ;;
  help|-h|--help) usage ;;
  *) echo "Unknown command: $1" >&2; echo; usage; exit 1 ;;
esac
