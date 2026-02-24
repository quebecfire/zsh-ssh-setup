# ==============================================================================
# ssh-setup.zsh — SSH key lifecycle management
# Strategy: One ed25519 key per machine. Same pubkey deployed everywhere.
# ==============================================================================

# --- Colors ---
_ssh_red()    { echo -e "\033[0;31m$*\033[0m"; }
_ssh_green()  { echo -e "\033[0;32m$*\033[0m"; }
_ssh_yellow() { echo -e "\033[1;33m$*\033[0m"; }
_ssh_blue()   { echo -e "\033[0;34m$*\033[0m"; }
_ssh_cyan()   { echo -e "\033[0;36m$*\033[0m"; }
_ssh_bold()   { echo -e "\033[1m$*\033[0m"; }

# ==============================================================================
# ssh-pub — Print current public key for copy-paste
# ==============================================================================
ssh-pub() {
    local key_file="$HOME/.ssh/id_ed25519.pub"

    if [[ ! -f "$key_file" ]]; then
        _ssh_red "No public key found at $key_file"
        echo "Run 'ssh-gen' to generate one."
        return 1
    fi

    echo ""
    _ssh_bold "═══════════════════════════════════════════════════════════"
    cat "$key_file"
    _ssh_bold "═══════════════════════════════════════════════════════════"
    echo ""

    # Copy to clipboard if possible
    if command -v xclip &>/dev/null; then
        cat "$key_file" | xclip -selection clipboard
        _ssh_green "Copied to clipboard (xclip)"
    elif command -v xsel &>/dev/null; then
        cat "$key_file" | xsel --clipboard
        _ssh_green "Copied to clipboard (xsel)"
    elif command -v wl-copy &>/dev/null; then
        cat "$key_file" | wl-copy
        _ssh_green "Copied to clipboard (wl-copy)"
    elif command -v pbcopy &>/dev/null; then
        cat "$key_file" | pbcopy
        _ssh_green "Copied to clipboard (pbcopy)"
    fi
}

# ==============================================================================
# ssh-info — Show key details, fingerprint, permissions, agent status
# ==============================================================================
ssh-info() {
    local ssh_dir="$HOME/.ssh"
    local key_file="$ssh_dir/id_ed25519"

    echo ""
    _ssh_bold "SSH Key Info"
    _ssh_bold "════════════"
    echo ""

    # Key exists?
    if [[ ! -f "$key_file" ]]; then
        _ssh_red "No key found at $key_file"
        echo "Run 'ssh-gen' to generate one."
        return 1
    fi

    # Key details
    local fingerprint comment
    fingerprint=$(ssh-keygen -l -f "$key_file" 2>/dev/null)
    comment=$(awk '{print $NF}' "$key_file.pub" 2>/dev/null)

    echo "  Key file:     $key_file"
    echo "  Comment:      $comment"
    echo "  Fingerprint:  $fingerprint"
    echo ""

    # Permissions check
    _ssh_bold "Permissions"
    local ok=true

    local dir_perms=$(stat -c %a "$ssh_dir" 2>/dev/null || stat -f %Lp "$ssh_dir" 2>/dev/null)
    if [[ "$dir_perms" == "700" ]]; then
        _ssh_green "  ✓ ~/.ssh/          $dir_perms"
    else
        _ssh_red   "  ✗ ~/.ssh/          $dir_perms (should be 700)"
        ok=false
    fi

    local key_perms=$(stat -c %a "$key_file" 2>/dev/null || stat -f %Lp "$key_file" 2>/dev/null)
    if [[ "$key_perms" == "600" ]]; then
        _ssh_green "  ✓ id_ed25519       $key_perms"
    else
        _ssh_red   "  ✗ id_ed25519       $key_perms (should be 600)"
        ok=false
    fi

    local pub_perms=$(stat -c %a "$key_file.pub" 2>/dev/null || stat -f %Lp "$key_file.pub" 2>/dev/null)
    if [[ "$pub_perms" == "644" ]]; then
        _ssh_green "  ✓ id_ed25519.pub   $pub_perms"
    else
        _ssh_yellow "  ! id_ed25519.pub   $pub_perms (ideally 644)"
        ok=false
    fi

    if [[ -f "$ssh_dir/config" ]]; then
        local cfg_perms=$(stat -c %a "$ssh_dir/config" 2>/dev/null || stat -f %Lp "$ssh_dir/config" 2>/dev/null)
        if [[ "$cfg_perms" == "600" ]]; then
            _ssh_green "  ✓ config           $cfg_perms"
        else
            _ssh_red   "  ✗ config           $cfg_perms (should be 600)"
            ok=false
        fi
    fi

    echo ""

    # Agent status
    _ssh_bold "Agent"
    if ssh-add -l &>/dev/null; then
        local loaded
        loaded=$(ssh-add -l 2>/dev/null | wc -l)
        _ssh_green "  ✓ ssh-agent running ($loaded key(s) loaded)"
    elif [[ $? -eq 1 ]]; then
        _ssh_yellow "  ! ssh-agent running but no keys loaded"
        echo "    Run: ssh-add"
    else
        _ssh_yellow "  ! ssh-agent not running"
        echo "    Run: eval \$(ssh-agent) && ssh-add"
    fi

    echo ""

    if $ok; then
        _ssh_green "All checks passed."
    else
        _ssh_yellow "Run 'ssh-fix-perms' to fix permission issues."
    fi
    echo ""
}

# ==============================================================================
# ssh-fix-perms — Fix ~/.ssh permissions
# ==============================================================================
ssh-fix-perms() {
    local ssh_dir="$HOME/.ssh"

    _ssh_blue "[FIX] Setting permissions..."

    chmod 700 "$ssh_dir"
    echo "  ~/.ssh/          → 700"

    # Private keys: 600
    for f in "$ssh_dir"/id_* "$ssh_dir"/*_rsa "$ssh_dir"/*_deploy; do
        if [[ -f "$f" && "$f" != *.pub ]]; then
            chmod 600 "$f"
            echo "  $(basename "$f")  → 600"
        fi
    done

    # Public keys: 644
    for f in "$ssh_dir"/*.pub; do
        if [[ -f "$f" ]]; then
            chmod 644 "$f"
            echo "  $(basename "$f") → 644"
        fi
    done

    # Config: 600
    if [[ -f "$ssh_dir/config" ]]; then
        chmod 600 "$ssh_dir/config"
        echo "  config           → 600"
    fi

    # known_hosts: 644
    if [[ -f "$ssh_dir/known_hosts" ]]; then
        chmod 644 "$ssh_dir/known_hosts"
        echo "  known_hosts      → 644"
    fi

    echo ""
    _ssh_green "Done."
}

# ==============================================================================
# ssh-deploy — Deploy public key to a remote host
# ==============================================================================
ssh-deploy() {
    local target="$1"

    if [[ -z "$target" ]]; then
        echo "Usage: ssh-deploy user@host"
        return 1
    fi

    local key_file="$HOME/.ssh/id_ed25519.pub"
    if [[ ! -f "$key_file" ]]; then
        _ssh_red "No public key found. Run 'ssh-gen' first."
        return 1
    fi

    _ssh_blue "Deploying public key to $target..."
    ssh-copy-id -i "$key_file" "$target"

    if [[ $? -eq 0 ]]; then
        _ssh_green "Key deployed. Test with: ssh $target"
    else
        _ssh_red "Deploy failed."
        return 1
    fi
}

# ==============================================================================
# ssh-gen — Generate a new ed25519 key for this machine
# ==============================================================================
ssh-gen() {
    local ssh_dir="$HOME/.ssh"
    local key_type="ed25519"
    local key_user="$(whoami)"
    local key_host="$(hostname)"
    local key_year="$(date +%Y)"
    local key_comment="${key_user}@${key_host}-${key_year}"
    local key_file="$ssh_dir/id_${key_type}"
    local backup_dir="$ssh_dir/backup-$(date +%Y-%m-%d)"

    local use_passphrase=true
    local force=false
    local write_config=true

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-passphrase) use_passphrase=false; shift ;;
            --force)         force=true; shift ;;
            --no-config)     write_config=false; shift ;;
            -h|--help)
                echo "Usage: ssh-gen [OPTIONS]"
                echo ""
                echo "Generate a new ed25519 SSH key for this machine."
                echo ""
                echo "OPTIONS:"
                echo "    --no-passphrase   Skip passphrase (less secure, useful for CI)"
                echo "    --no-config       Don't overwrite ~/.ssh/config"
                echo "    --force           Skip confirmation prompt"
                echo "    -h, --help        Show this help"
                echo ""
                echo "Generated key:"
                echo "    File:    $key_file"
                echo "    Comment: $key_comment"
                return 0
                ;;
            *)
                _ssh_red "Unknown option: $1"
                return 1
                ;;
        esac
    done

    echo ""
    _ssh_bold "══════════════════════════════════════"
    _ssh_bold "  SSH Key Generator"
    _ssh_bold "══════════════════════════════════════"
    echo ""
    echo "  Key type:    $key_type"
    echo "  Key file:    $key_file"
    echo "  Comment:     $key_comment"
    echo "  Passphrase:  $(if $use_passphrase; then echo 'yes (prompted)'; else echo 'none'; fi)"
    echo "  SSH config:  $(if $write_config; then echo 'will be written'; else echo 'skip (--no-config)'; fi)"
    echo ""

    # --- Ensure ~/.ssh exists ---
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        _ssh_green "Created $ssh_dir"
    fi

    # --- Check existing key ---
    if [[ -f "$key_file" ]]; then
        local existing_comment
        existing_comment=$(awk '{print $NF}' "$key_file.pub" 2>/dev/null || echo "unknown")
        _ssh_yellow "Existing key: $key_file ($existing_comment)"
        echo ""

        if ! $force; then
            echo "This will REPLACE your current key."
            echo "You'll need to re-deploy the new pubkey to:"
            echo "  - GitHub / GitLab"
            echo "  - Remote servers"
            echo "  - Embedded devices"
            echo ""
            echo -n "Continue? [y/N] "
            read -r confirm
            if [[ "$confirm" != [yY] ]]; then
                _ssh_blue "Aborted."
                return 0
            fi
        fi
    fi

    # --- Backup ---
    _ssh_blue "[STEP] Backing up existing keys..."

    local has_backup=false
    for f in "$ssh_dir"/id_* "$ssh_dir"/*_rsa "$ssh_dir"/*_deploy; do
        if [[ -f "$f" ]]; then
            has_backup=true
            break
        fi
    done

    if $has_backup; then
        mkdir -p "$backup_dir"
        for f in "$ssh_dir"/id_* "$ssh_dir"/*_rsa "$ssh_dir"/*_deploy; do
            if [[ -f "$f" ]]; then
                cp -p "$f" "$backup_dir/"
                echo "  $(basename "$f") → backup/"
            fi
        done
        if [[ -f "$ssh_dir/config" ]]; then
            cp -p "$ssh_dir/config" "$backup_dir/"
            echo "  config → backup/"
        fi
        _ssh_green "Backup: $backup_dir"
    else
        echo "  No existing keys to backup."
    fi

    echo ""

    # --- Generate ---
    _ssh_blue "[STEP] Generating ed25519 key..."

    rm -f "$key_file" "$key_file.pub"

    if $use_passphrase; then
        echo ""
        _ssh_cyan "Enter a passphrase (ssh-agent will cache it so you type it once per session):"
        echo ""
        ssh-keygen -t "$key_type" -C "$key_comment" -f "$key_file"
    else
        ssh-keygen -t "$key_type" -C "$key_comment" -f "$key_file" -N ""
    fi

    if [[ $? -ne 0 ]]; then
        _ssh_red "Key generation failed."
        return 1
    fi

    chmod 600 "$key_file"
    chmod 644 "$key_file.pub"
    echo ""
    _ssh_green "Key generated: $key_file"
    echo "  Fingerprint: $(ssh-keygen -l -f "$key_file")"
    echo ""

    # --- SSH Config ---
    if $write_config; then
        _ssh_blue "[STEP] Writing ~/.ssh/config..."

        cat > "$ssh_dir/config" <<'SSHEOF'
# SSH Client Configuration
# Generated by zsh-ssh-setup plugin
# Feel free to add host entries below the defaults.

Host *
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
    AddKeysToAgent yes

Host github.com
    HostName github.com
    User git

Host gitlab.com
    HostName gitlab.com
    User git
SSHEOF

        chmod 600 "$ssh_dir/config"
        mkdir -p "$ssh_dir/sockets"
        _ssh_green "Config written."
    fi

    echo ""

    # --- Display public key ---
    _ssh_blue "[STEP] Your public key:"
    echo ""
    _ssh_bold "═══════════════════════════════════════════════════════════"
    cat "$key_file.pub"
    _ssh_bold "═══════════════════════════════════════════════════════════"
    echo ""

    # Clipboard
    if command -v xclip &>/dev/null; then
        cat "$key_file.pub" | xclip -selection clipboard
        _ssh_green "Copied to clipboard (xclip)"
    elif command -v xsel &>/dev/null; then
        cat "$key_file.pub" | xsel --clipboard
        _ssh_green "Copied to clipboard (xsel)"
    elif command -v wl-copy &>/dev/null; then
        cat "$key_file.pub" | wl-copy
        _ssh_green "Copied to clipboard (wl-copy)"
    elif command -v pbcopy &>/dev/null; then
        cat "$key_file.pub" | pbcopy
        _ssh_green "Copied to clipboard (pbcopy)"
    fi

    echo ""

    # --- Deploy instructions ---
    _ssh_bold "Deploy your public key to:"
    echo ""
    echo "  GitHub:      https://github.com/settings/ssh/new"
    if command -v gh &>/dev/null; then
        echo "    or run:    gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$key_comment\""
    fi
    echo ""
    echo "  GitLab:      https://gitlab.com/-/user_settings/ssh_keys"
    if command -v glab &>/dev/null; then
        echo "    or run:    glab ssh-key add ~/.ssh/id_ed25519.pub --title \"$key_comment\""
    fi
    echo ""
    echo "  Server:      ssh-deploy user@hostname"
    echo ""

    # --- Verify ---
    _ssh_blue "[STEP] Verification..."
    ssh-info

    _ssh_bold "══════════════════════════════════════"
    _ssh_bold "  Done! Test: ssh -T git@github.com"
    _ssh_bold "══════════════════════════════════════"
    echo ""
}
