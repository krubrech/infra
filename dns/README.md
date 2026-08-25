# DNS-as-code — codecanoe.com via octoDNS + deSEC

The `codecanoe.com` zone is managed declaratively here. Namecheap stays the
**registrar**; **deSEC** hosts the DNS. Records live in
[`zones/codecanoe.com.yaml`](zones/codecanoe.com.yaml) and are pushed to deSEC
with octoDNS.

```
bin/dns          # dry-run: print the plan (what would change on deSEC)
bin/dns --doit   # apply the plan
```

octoDNS and the deSEC provider are supplied by the Nix devshell
(`octodns.withProviders`, provider packaged in `../nix/octodns-desec.nix`) —
no pip, no venv. `bin/dns` runs from this directory so `YamlProvider`'s
`directory: ./zones` resolves correctly.

## Setup (one-time)

1. **deSEC account** — sign up at <https://desec.io>, verify email.
2. **API token** — Token Management → create a token (or
   `POST /api/v1/auth/tokens/`).
3. **Store the token** — it's read from `$DESEC_TOKEN`, exported on shell entry
   from the sops-encrypted `.sops.env`:
   ```
   sops ../.sops.env        # add a line:  DESEC_TOKEN=<token>
   direnv reload
   ```
4. **Create the domain in deSEC** — this must exist before octoDNS can target
   it:
   ```
   curl -sS -X POST https://desec.io/api/v1/domains/ \
     -H "Authorization: Token $DESEC_TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{"name": "codecanoe.com"}'
   ```

## Migration cutover (do once, in order)

1. **Load records into deSEC while it's still dormant** (nameservers still point
   at Namecheap, so nothing is live yet):
   ```
   bin/dns          # review the plan — expect ~12 creates, 0 deletes
   bin/dns --doit
   ```
2. **Verify against deSEC directly**, before touching delegation:
   ```
   dig @ns1.desec.io codecanoe.com MX +short     # Google Workspace MX
   dig @ns1.desec.io koura.codecanoe.com A +short # 167.235.244.90
   dig @ns1.desec.io codecanoe.com TXT +short
   ```
3. **Switch nameservers at Namecheap** — Domain List → codecanoe.com →
   Nameservers → **Custom DNS** → `ns1.desec.io`, `ns2.desec.org`. Save.
   (Tip: lower Namecheap TTLs a day earlier to speed propagation.)
4. **Wait for propagation** (`dig codecanoe.com NS` shows the deSEC servers),
   then confirm mail still flows.
5. **(Optional) DNSSEC** — deSEC signs automatically. To enable validation, add
   deSEC's DS record at Namecheap → Advanced DNS → DNSSEC, *after* propagation
   is confirmed.

## Day-to-day

Edit `zones/codecanoe.com.yaml`, run `bin/dns` to preview, `bin/dns --doit` to
apply. octoDNS computes the diff and only touches what changed.

### Notes on the record set

- **MX (Google Workspace)** was *not* in Namecheap's Advanced DNS host table —
  it lived under Namecheap's "Mail Settings" preset, which stops working once
  the nameservers move. It's declared explicitly in the zone file. Do not drop
  it or mail breaks.
- **Apex + `www` point at `75.2.60.5`**, Namecheap's URL-forwarding IP. deSEC
  does DNS only — no HTTP redirects. If those are meant to redirect somewhere,
  that behaviour won't survive the move; repoint them at a real host or a
  redirect service.
- **TTLs** default to 3600 (`config.yaml`); deSEC enforces a 3600s minimum.
- No SPF/DMARC records exist today. If you want mail hardening later, add
  `v=spf1 include:_spf.google.com ~all` (TXT `@`) and a `_dmarc` TXT — but
  that's an improvement, not part of the migration.
