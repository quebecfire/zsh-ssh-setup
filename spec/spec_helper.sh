# shellcheck shell=sh
# spec/spec_helper.sh — shared test setup for zsh-ssh-setup

# Called by ShellSpec before each example
setup() {
  export ORIG_HOME="$HOME"
  export TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  export SSH_DIR="$TEST_HOME/.ssh"
  mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
}

# Called by ShellSpec after each example
cleanup() {
  export HOME="$ORIG_HOME"
  [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
  unset TEST_HOME SSH_DIR ORIG_HOME
}

# Helper: create a fake ed25519 private key file
create_ed25519_key() {
  local name="${1:-id_ed25519}"
  ssh-keygen -t ed25519 -f "$SSH_DIR/$name" -N "" -C "test@host-2025${2:+:$2}" -q
}

# Helper: create a fake RSA private key file
create_rsa_key() {
  local name="${1:-id_rsa}"
  ssh-keygen -t rsa -b 2048 -f "$SSH_DIR/$name" -N "" -C "test@host-2025${2:+:$2}" -q
}

# Helper: create an ECDSA private key file
create_ecdsa_key() {
  local name="${1:-id_ecdsa}"
  ssh-keygen -t ecdsa -b 256 -f "$SSH_DIR/$name" -N "" -C "test@host-2025${2:+:$2}" -q
}

# Helper: source the plugin
load_plugin() {
  # Force plain output for predictable test assertions
  export _SSH_IS_TTY=false
  source "${SHELLSPEC_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/ssh-setup.zsh"
}
