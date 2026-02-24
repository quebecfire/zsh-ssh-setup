# zsh-ssh-setup

ZSH plugin for SSH key lifecycle management. One ed25519 key per machine, deploy the public key everywhere.

## Strategy

- **One private key per computer** you work from
- **Same public key** goes to GitHub, GitLab, servers, embedded devices
- **New machine?** Clone this plugin, run `ssh-gen`, deploy pubkey
- **Retire a machine?** Remove its pubkey from services

## Install

```bash
# Clone into oh-my-zsh custom plugins
git clone https://github.com/YOUR_USER/zsh-ssh-setup.git \
    ~/.oh-my-zsh/custom/plugins/zsh-ssh-setup

# Add to plugins in ~/.zshrc
plugins=(... zsh-ssh-setup)

# Reload
source ~/.zshrc
```

## Commands

| Command | Description |
|---|---|
| `ssh-gen` | Generate new ed25519 key for this machine |
| `ssh-pub` | Print public key (+ copy to clipboard) |
| `ssh-info` | Key details, permissions, agent health check |
| `ssh-deploy user@host` | Deploy pubkey to remote host via ssh-copy-id |
| `ssh-fix-perms` | Fix ~/.ssh permissions (700/600/644) |

## ssh-gen

Generates a new key with comment format `user@hostname-YYYY`.

```bash
# Interactive (prompts for passphrase)
ssh-gen

# No passphrase (CI/automation)
ssh-gen --no-passphrase

# Skip confirmation
ssh-gen --force

# Don't overwrite existing ~/.ssh/config
ssh-gen --no-config
```

What `ssh-gen` does:
1. Backs up existing keys to `~/.ssh/backup-YYYY-MM-DD/`
2. Generates ed25519 key at `~/.ssh/id_ed25519`
3. Writes clean `~/.ssh/config` (ControlMaster, AddKeysToAgent, GitHub/GitLab hosts)
4. Displays public key (auto-copies to clipboard)
5. Shows deployment instructions
6. Runs verification checks

## SSH Config

`ssh-gen` writes a `~/.ssh/config` with sensible defaults:

- `IdentitiesOnly yes` — only send configured keys
- `AddKeysToAgent yes` — auto ssh-add on first use
- `ControlMaster auto` — connection multiplexing (faster)
- `ServerAliveInterval 60` — keep connections alive
- Pre-configured GitHub and GitLab host entries

## Key Naming Convention

```
File:    ~/.ssh/id_ed25519
Comment: morinv@xps8960-2026
```

The comment identifies **who**, **which machine**, and **when** (year for rotation tracking).
