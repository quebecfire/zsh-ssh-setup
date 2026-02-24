# zsh-ssh-setup — One ed25519 key per machine, deploy everywhere.
#
# Commands:
#   ssh-gen          Generate new key for this machine
#   ssh-pub          Print public key
#   ssh-info         Show key details & health check
#   ssh-deploy       Deploy pubkey to a remote host
#   ssh-fix-perms    Fix ~/.ssh permissions
#
# Install:
#   git clone <repo> ~/.oh-my-zsh/custom/plugins/zsh-ssh-setup
#   plugins=(... zsh-ssh-setup)

source "${0:A:h}/ssh-setup.zsh"
