# zsh-ssh-setup

Oh-my-zsh plugin for SSH key management. One ed25519 key per machine, deploy the public key everywhere.

## Quick Start

Requires [oh-my-zsh](https://ohmyz.sh/).

```bash
git clone https://github.com/YOUR_USER/zsh-ssh-setup.git \
    ~/.oh-my-zsh/custom/plugins/zsh-ssh-setup

~/.oh-my-zsh/custom/plugins/zsh-ssh-setup/install.sh

source ~/.zshrc

ssh-gen
```

That's it. The installer adds the plugin to your `.zshrc` and explains every command it runs.

## Commands

| Command | Description |
|---|---|
| `ssh-gen` | Generate a new ed25519 key for this machine |
| `ssh-pub` | Print your public key (auto-copies to clipboard) |
| `ssh-info` | Key fingerprint, permissions check, agent status |
| `ssh-deploy user@host` | Deploy your pubkey to a remote host |
| `ssh-fix-perms` | Fix `~/.ssh` permissions (700/600/644) |

## What `ssh-gen` does

1. Backs up existing keys to `~/.ssh/backup-YYYY-MM-DD/`
2. Generates an ed25519 key with comment `user@hostname-YYYY`
3. Writes a clean `~/.ssh/config` (connection multiplexing, GitHub/GitLab hosts)
4. Displays your public key for copy-paste
5. Runs a health check on permissions and ssh-agent

Options:
- `--no-passphrase` — skip passphrase (useful for CI)
- `--no-config` — don't overwrite `~/.ssh/config`
- `--force` — skip confirmation prompt

## Why

- **New machine?** Clone, install, `ssh-gen`, deploy pubkey. Done.
- **Retire a machine?** Remove its pubkey from your services.
- **Multiple computers?** Each has its own key. Add all pubkeys where needed.
