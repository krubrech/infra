# GitHub SSH Setup for Rabbit Machine

## Prerequisites
You need to have the krubrech-rabbit GitHub machine user account set up with access to:
- krubrech/infra
- krubrech/nixfiles

## Step 1: Generate SSH Key Pair (Do this locally, not on rabbit)

```bash
ssh-keygen -t ed25519 -C "krubrech-rabbit" -f ~/.ssh/krubrech-rabbit
```

This creates:
- `~/.ssh/krubrech-rabbit` (private key)
- `~/.ssh/krubrech-rabbit.pub` (public key)

## Step 2: Add Public Key to GitHub

1. Log in to GitHub as krubrech-rabbit
2. Go to https://github.com/settings/keys
3. Click "New SSH key"
4. Title: `rabbit machine`
5. Paste the contents of `~/.ssh/krubrech-rabbit.pub`
6. Click "Add SSH key"

## Step 3: Encrypt Private Key with SOPS

```bash
# In your infra repo directory
sops secrets/secrets.yaml
```

Add the following entry (paste the entire private key including BEGIN/END lines):

```yaml
github-ssh-key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [paste contents of ~/.ssh/krubrech-rabbit here]
  -----END OPENSSH PRIVATE KEY-----
```

Save and exit sops.

## Step 4: Deploy to Rabbit

```bash
./deploy-rabbit.sh
```

The klaus user on rabbit will now have GitHub SSH access configured automatically.

## Testing

SSH into rabbit as klaus and test:

```bash
ssh klaus@rabbit
git clone git@github.com:krubrech/nixfiles.git
cd nixfiles
# Make a change
git commit -am "test"
git push
```
