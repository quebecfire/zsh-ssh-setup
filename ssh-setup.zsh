# ==============================================================================
# ssh-setup.zsh — SSH key lifecycle management
# Strategy: One ed25519 key per machine. Same pubkey deployed everywhere.
#           Optional named keys for multi-key setups (work, project, etc.)
#
# Naming convention:
#   Default:  ~/.ssh/id_ed25519         comment: user@hostname-YYYY
#   Named:    ~/.ssh/id_ed25519_work    comment: user@hostname-YYYY:work
# ==============================================================================

# --- Output mode ---
_SSH_IS_TTY=true

_ssh_init_output() {
    _SSH_IS_TTY=true
    [[ -t 1 ]] || _SSH_IS_TTY=false

    # Allow explicit override
    local arg
    for arg in "$@"; do
        case "$arg" in
            --plain) _SSH_IS_TTY=false ;;
            --color) _SSH_IS_TTY=true ;;
        esac
    done
}

# Strip --plain/--color from args, return remaining in _SSH_ARGS
_ssh_strip_output_args() {
    _SSH_ARGS=()
    local arg
    for arg in "$@"; do
        case "$arg" in
            --plain|--color) ;;
            *) _SSH_ARGS+=("$arg") ;;
        esac
    done
}

# --- Colors ---
_ssh_red()    { if [[ "$_SSH_IS_TTY" == true ]]; then echo -e "\033[0;31m$*\033[0m"; else echo "$*"; fi; }
_ssh_green()  { if [[ "$_SSH_IS_TTY" == true ]]; then echo -e "\033[0;32m$*\033[0m"; else echo "$*"; fi; }
_ssh_yellow() { if [[ "$_SSH_IS_TTY" == true ]]; then echo -e "\033[1;33m$*\033[0m"; else echo "$*"; fi; }
_ssh_blue()   { if [[ "$_SSH_IS_TTY" == true ]]; then echo -e "\033[0;34m$*\033[0m"; else echo "$*"; fi; }
_ssh_cyan()   { if [[ "$_SSH_IS_TTY" == true ]]; then echo -e "\033[0;36m$*\033[0m"; else echo "$*"; fi; }
_ssh_bold()   { if [[ "$_SSH_IS_TTY" == true ]]; then echo -e "\033[1m$*\033[0m"; else echo "$*"; fi; }

# --- Clipboard helper ---
_ssh_to_clipboard() {
    [[ "$_SSH_IS_TTY" == true ]] || return 0
    local file="$1"
    if command -v xclip &>/dev/null; then
        cat "$file" | xclip -selection clipboard
        _ssh_green "Copied to clipboard (xclip)"
    elif command -v xsel &>/dev/null; then
        cat "$file" | xsel --clipboard
        _ssh_green "Copied to clipboard (xsel)"
    elif command -v wl-copy &>/dev/null; then
        cat "$file" | wl-copy
        _ssh_green "Copied to clipboard (wl-copy)"
    elif command -v pbcopy &>/dev/null; then
        cat "$file" | pbcopy
        _ssh_green "Copied to clipboard (pbcopy)"
    fi
}

# --- Resolve key file from optional label ---
# Returns the key file path. Sets _SSH_LABEL for use in comments.
_ssh_resolve_key() {
    local label="$1"
    local ssh_dir="${SSH_DIR:-$HOME/.ssh}"
    _SSH_LABEL=""

    if [[ -z "$label" ]]; then
        echo "$ssh_dir/id_ed25519"
    else
        _SSH_LABEL="$label"
        echo "$ssh_dir/id_ed25519_${label}"
    fi
}

# --- Build comment from label ---
_ssh_build_comment() {
    local label="$1"
    local base="$(whoami)@$(hostname)-$(date +%Y)"

    if [[ -n "$label" ]]; then
        echo "${base}:${label}"
    else
        echo "$base"
    fi
}

# --- Generic key detection ---
# Populates _SSH_PRIVATE_KEYS array with all private key paths in SSH_DIR
_ssh_find_all_private_keys() {
    local ssh_dir="${SSH_DIR:-$HOME/.ssh}"
    _SSH_PRIVATE_KEYS=()

    [[ -d "$ssh_dir" ]] || return 0

    local file base first_line
    for file in "$ssh_dir"/*(N.,@); do
        base=$(basename "$file")

        # Skip well-known non-key files
        case "$base" in
            *.pub|known_hosts*|config|authorized_keys*|*.sock|*.log|*.old|sockets|backup-*|environment) continue ;;
        esac

        # Check first line for PRIVATE KEY marker
        first_line=$(head -n 1 "$file" 2>/dev/null) || continue
        if [[ "$first_line" == *"PRIVATE KEY"* ]]; then
            _SSH_PRIVATE_KEYS+=("$file")
        fi
    done
}

# Returns key type (ED25519, RSA, ECDSA, DSA) for a private key file
_ssh_key_type() {
    local key_file="$1"
    local info
    info=$(ssh-keygen -l -f "$key_file" 2>/dev/null) || { echo "UNKNOWN"; return 1; }

    # ssh-keygen -l output: "256 SHA256:... comment (ED25519)"
    # Extract type between last parentheses
    echo "$info" | sed 's/.*(\([^)]*\))$/\1/'
}

# Returns true if basename matches id_ed25519 or id_ed25519_*
_ssh_is_managed_key() {
    local key_file="$1"
    local base=$(basename "$key_file")
    [[ "$base" == id_ed25519 || "$base" == id_ed25519_* ]]
}

# --- List all SSH keys ---
_ssh_list_keys() {
    _ssh_find_all_private_keys
    local found=0

    local managed=()
    local other=()

    local key
    for key in "${_SSH_PRIVATE_KEYS[@]}"; do
        local name=$(basename "$key")
        local pub="${key}.pub"
        local comment=""
        [[ -f "$pub" ]] && comment=$(awk '{print $NF}' "$pub" 2>/dev/null)
        local fingerprint=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $2}')
        local ktype=$(_ssh_key_type "$key")

        local label=""
        if [[ "$name" == "id_ed25519" ]]; then
            label="(default)"
        elif [[ "$name" == id_ed25519_* ]]; then
            label="${name#id_ed25519_}"
        else
            label="$name"
        fi

        local line=$(printf "  %-20s %-8s %-40s %s" "$label" "$ktype" "$comment" "$fingerprint")

        if _ssh_is_managed_key "$key"; then
            managed+=("$line")
        else
            other+=("$line")
        fi
        found=$((found + 1))
    done

    if (( ${#managed[@]} > 0 )); then
        _ssh_cyan "  Managed keys (ed25519):"
        for line in "${managed[@]}"; do
            echo "$line"
        done
    fi

    if (( ${#other[@]} > 0 )); then
        [[ ${#managed[@]} -gt 0 ]] && echo ""
        _ssh_cyan "  Other keys:"
        for line in "${other[@]}"; do
            echo "$line"
        done
    fi

    return $found
}

# ==============================================================================
# ssh-pub — Print public key(s) for copy-paste
#   ssh-pub              show default key (or list if multiple)
#   ssh-pub work         show named key
#   ssh-pub --all        show all keys
# ==============================================================================
ssh-pub() {
    _ssh_init_output "$@"
    _ssh_strip_output_args "$@"
    set -- "${_SSH_ARGS[@]}"

    local ssh_dir="${SSH_DIR:-$HOME/.ssh}"

    # --all: show every key
    if [[ "$1" == "--all" ]]; then
        echo ""
        _ssh_bold "All SSH public keys:"
        echo ""
        _ssh_find_all_private_keys
        local found=false
        for key in "${_SSH_PRIVATE_KEYS[@]}"; do
            local pub="${key}.pub"
            [[ -f "$pub" ]] || continue
            found=true
            local name=$(basename "$key")
            local label=""
            local ktype=$(_ssh_key_type "$key")
            if [[ "$name" == "id_ed25519" ]]; then
                label="default"
            elif [[ "$name" == id_ed25519_* ]]; then
                label="${name#id_ed25519_}"
            else
                label="$name"
            fi
            _ssh_cyan "  [$label] ($ktype)"
            cat "$pub"
            echo ""
        done
        if ! $found; then
            _ssh_red "No SSH keys found."
            echo "Run 'ssh-gen' to generate one."
        fi
        return 0
    fi

    # Resolve which key
    local key_file=$(_ssh_resolve_key "$1")

    if [[ ! -f "$key_file.pub" ]]; then
        # No specific key found — if no arg given, maybe there are named keys
        if [[ -z "$1" ]]; then
            _ssh_find_all_private_keys
            if (( ${#_SSH_PRIVATE_KEYS[@]} > 0 )); then
                echo ""
                _ssh_yellow "No default key. Available keys:"
                echo ""
                _ssh_list_keys
                echo ""
                echo "Usage: ssh-pub <label>  or  ssh-pub --all"
                return 0
            fi
        fi
        _ssh_red "No public key found: $key_file.pub"
        echo "Run 'ssh-gen' to generate one."
        return 1
    fi

    echo ""
    [[ "$_SSH_IS_TTY" == true ]] && _ssh_bold "═══════════════════════════════════════════════════════════"
    cat "$key_file.pub"
    [[ "$_SSH_IS_TTY" == true ]] && _ssh_bold "═══════════════════════════════════════════════════════════"
    echo ""

    _ssh_to_clipboard "$key_file.pub"
}

# ==============================================================================
# ssh-info — Show key details, fingerprint, permissions, agent status
#   ssh-info             show all keys info
#   ssh-info work        show specific key info
# ==============================================================================
ssh-info() {
    _ssh_init_output "$@"
    _ssh_strip_output_args "$@"
    set -- "${_SSH_ARGS[@]}"

    local ssh_dir="${SSH_DIR:-$HOME/.ssh}"

    echo ""
    _ssh_bold "SSH Key Info"
    [[ "$_SSH_IS_TTY" == true ]] && _ssh_bold "════════════"
    echo ""

    # --- List keys ---
    if [[ -n "$1" ]]; then
        # Specific key
        local key_file=$(_ssh_resolve_key "$1")
        # Fallback: try literal filename in ssh_dir
        if [[ ! -f "$key_file" ]]; then
            key_file="${ssh_dir}/$1"
        fi
        if [[ ! -f "$key_file" ]]; then
            _ssh_red "Key not found: $1"
            return 1
        fi
        local fingerprint=$(ssh-keygen -l -f "$key_file" 2>/dev/null)
        local comment=""
        [[ -f "$key_file.pub" ]] && comment=$(awk '{print $NF}' "$key_file.pub" 2>/dev/null)
        local ktype=$(_ssh_key_type "$key_file")
        echo "  File:         $key_file"
        echo "  Type:         $ktype"
        echo "  Comment:      $comment"
        echo "  Fingerprint:  $fingerprint"
    else
        # All keys
        _ssh_bold "Keys"
        _ssh_find_all_private_keys
        local has_keys=false

        local managed_keys=()
        local other_keys=()

        local key
        for key in "${_SSH_PRIVATE_KEYS[@]}"; do
            has_keys=true
            if _ssh_is_managed_key "$key"; then
                managed_keys+=("$key")
            else
                other_keys+=("$key")
            fi
        done

        if (( ${#managed_keys[@]} > 0 )); then
            _ssh_cyan "  Managed keys (ed25519):"
            echo ""
            for key in "${managed_keys[@]}"; do
                local name=$(basename "$key")
                local pub="${key}.pub"
                local comment=""
                [[ -f "$pub" ]] && comment=$(awk '{print $NF}' "$pub" 2>/dev/null)
                local fingerprint=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $2}')
                local ktype=$(_ssh_key_type "$key")

                local label=""
                if [[ "$name" == "id_ed25519" ]]; then
                    label="default"
                else
                    label="${name#id_ed25519_}"
                fi

                printf "  ${label}:\n"
                echo "    File:         $key"
                echo "    Type:         $ktype"
                echo "    Comment:      $comment"
                echo "    Fingerprint:  $fingerprint"
                echo ""
            done
        fi

        if (( ${#other_keys[@]} > 0 )); then
            _ssh_cyan "  Other keys:"
            echo ""
            for key in "${other_keys[@]}"; do
                local name=$(basename "$key")
                local pub="${key}.pub"
                local comment=""
                [[ -f "$pub" ]] && comment=$(awk '{print $NF}' "$pub" 2>/dev/null)
                local fingerprint=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $2}')
                local ktype=$(_ssh_key_type "$key")

                printf "  ${name}:\n"
                echo "    File:         $key"
                echo "    Type:         $ktype"
                echo "    Comment:      $comment"
                echo "    Fingerprint:  $fingerprint"
                echo ""
            done
        fi

        if ! $has_keys; then
            _ssh_red "  No SSH keys found."
            echo "  Run 'ssh-gen' to generate one."
            echo ""
        fi
    fi

    echo ""

    # --- Permissions ---
    _ssh_bold "Permissions"
    local ok=true

    local dir_perms=$(stat -c %a "$ssh_dir" 2>/dev/null || stat -f %Lp "$ssh_dir" 2>/dev/null)
    if [[ "$dir_perms" == "700" ]]; then
        _ssh_green "  ✓ ~/.ssh/          $dir_perms"
    else
        _ssh_red   "  ✗ ~/.ssh/          $dir_perms (should be 700)"
        ok=false
    fi

    # Check all private keys
    _ssh_find_all_private_keys
    for priv in "${_SSH_PRIVATE_KEYS[@]}"; do
        local name=$(basename "$priv")
        local perms=$(stat -c %a "$priv" 2>/dev/null || stat -f %Lp "$priv" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            _ssh_green "  ✓ $name  $perms"
        else
            _ssh_red   "  ✗ $name  $perms (should be 600)"
            ok=false
        fi
    done

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

    # --- Agent ---
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
    _ssh_init_output "$@"
    _ssh_strip_output_args "$@"
    set -- "${_SSH_ARGS[@]}"

    local ssh_dir="${SSH_DIR:-$HOME/.ssh}"

    _ssh_blue "[FIX] Setting permissions..."

    if [[ ! -d "$ssh_dir" ]]; then
        _ssh_red "Directory not found: $ssh_dir"
        return 1
    fi

    chmod 700 "$ssh_dir"
    echo "  ~/.ssh/          → 700"

    # Private keys: 600
    _ssh_find_all_private_keys
    for f in "${_SSH_PRIVATE_KEYS[@]}"; do
        chmod 600 "$f"
        echo "  $(basename "$f")  → 600"
    done

    # Public keys: 644
    for f in "$ssh_dir"/*.pub(N); do
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
#   ssh-deploy user@host          deploy default key
#   ssh-deploy user@host work     deploy named key
# ==============================================================================
ssh-deploy() {
    _ssh_init_output "$@"
    _ssh_strip_output_args "$@"
    set -- "${_SSH_ARGS[@]}"

    local target="$1"
    local label="$2"

    if [[ -z "$target" ]]; then
        echo "Usage: ssh-deploy user@host [label]"
        echo ""
        echo "Examples:"
        echo "  ssh-deploy ubuntu@192.168.1.10          # deploy default key"
        echo "  ssh-deploy ubuntu@192.168.1.10 work     # deploy named key"
        return 1
    fi

    local key_file=$(_ssh_resolve_key "$label")

    if [[ ! -f "$key_file.pub" ]]; then
        _ssh_red "No public key found: $key_file.pub"
        echo "Run 'ssh-gen${label:+ $label}' first."
        return 1
    fi

    local comment=$(awk '{print $NF}' "$key_file.pub" 2>/dev/null)
    _ssh_blue "Deploying key ($comment) to $target..."
    ssh-copy-id -i "$key_file.pub" "$target"

    if [[ $? -eq 0 ]]; then
        _ssh_green "Key deployed. Test with: ssh $target"
    else
        _ssh_red "Deploy failed."
        return 1
    fi
}

# ==============================================================================
# ssh-gen — Generate a new ed25519 key
#   ssh-gen                     interactive (choose default or named)
#   ssh-gen work                generate named key directly
#   ssh-gen --no-passphrase     skip passphrase
#   ssh-gen --no-config         don't touch ~/.ssh/config
# ==============================================================================
ssh-gen() {
    _ssh_init_output "$@"
    _ssh_strip_output_args "$@"
    set -- "${_SSH_ARGS[@]}"

    local ssh_dir="${SSH_DIR:-$HOME/.ssh}"
    local key_type="ed25519"

    local label=""
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
                echo "Usage: ssh-gen [LABEL] [OPTIONS]"
                echo ""
                echo "Generate a new ed25519 SSH key."
                echo ""
                echo "LABEL (optional):"
                echo "    Name for the key. Creates ~/.ssh/id_ed25519_<label>"
                echo "    with comment user@hostname-YYYY:<label>"
                echo "    If omitted, offers an interactive choice."
                echo ""
                echo "OPTIONS:"
                echo "    --no-passphrase   Skip passphrase (less secure, useful for CI)"
                echo "    --no-config       Don't touch ~/.ssh/config"
                echo "    --force           Skip confirmation prompt"
                echo "    --plain           Force plain output (no colors)"
                echo "    --color           Force colored output"
                echo "    -h, --help        Show this help"
                echo ""
                echo "Examples:"
                echo "    ssh-gen                 # interactive"
                echo "    ssh-gen work            # ~/.ssh/id_ed25519_work"
                echo "    ssh-gen canex           # ~/.ssh/id_ed25519_canex"
                echo "    ssh-gen --no-passphrase # default key, no passphrase"
                return 0
                ;;
            -*)
                _ssh_red "Unknown option: $1"
                return 1
                ;;
            *)
                label="$1"; shift
                ;;
        esac
    done

    echo ""
    if [[ "$_SSH_IS_TTY" == true ]]; then
        _ssh_bold "══════════════════════════════════════"
        _ssh_bold "  SSH Key Generator"
        _ssh_bold "══════════════════════════════════════"
    else
        _ssh_bold "SSH Key Generator"
    fi
    echo ""

    # --- Ensure ~/.ssh exists ---
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        _ssh_green "Created $ssh_dir"
    fi

    # --- Interactive label selection if none given ---
    if [[ -z "$label" ]]; then
        # Show existing keys
        _ssh_find_all_private_keys
        if (( ${#_SSH_PRIVATE_KEYS[@]} > 0 )); then
            _ssh_bold "Existing keys:"
            echo ""
            _ssh_list_keys
            echo ""
        fi

        echo "What do you want to create?"
        echo ""
        echo "  1) Default key       ~/.ssh/id_ed25519"
        echo "  2) Named key         ~/.ssh/id_ed25519_<label>"
        echo "  q) Cancel"
        echo ""
        echo -n "Choice [1/2/q]: "
        read -r choice

        case "$choice" in
            1) label="" ;;
            2)
                echo -n "Label (e.g. work, canex, personal): "
                read -r label
                if [[ -z "$label" ]]; then
                    _ssh_red "Label cannot be empty."
                    return 1
                fi
                # Sanitize: lowercase, no spaces/special chars
                label=$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-_')
                ;;
            q|Q) _ssh_blue "Cancelled."; return 0 ;;
            *)   _ssh_red "Invalid choice."; return 1 ;;
        esac
    fi

    local key_comment=$(_ssh_build_comment "$label")
    local key_file=$(_ssh_resolve_key "$label")

    echo ""
    echo "  Key type:    $key_type"
    echo "  Key file:    $key_file"
    echo "  Comment:     $key_comment"
    echo "  Passphrase:  $(if $use_passphrase; then echo 'yes (prompted)'; else echo 'none'; fi)"
    echo ""

    # --- Check existing key ---
    if [[ -f "$key_file" ]]; then
        local existing_comment
        existing_comment=$(awk '{print $NF}' "$key_file.pub" 2>/dev/null || echo "unknown")
        _ssh_yellow "Existing key found: $key_file ($existing_comment)"
        echo ""

        if ! $force; then
            echo "  1) Replace it (backup first)"
            echo "  2) Keep it, abort"
            echo ""
            echo -n "Choice [1/2]: "
            read -r choice

            case "$choice" in
                1) ;; # continue
                *)
                    _ssh_blue "Kept existing key."
                    return 0
                    ;;
            esac
        fi
    fi

    # --- Backup ---
    local backup_dir="$ssh_dir/backup-$(date +%Y-%m-%d)"
    if [[ -f "$key_file" ]]; then
        _ssh_blue "[STEP] Backing up existing key..."
        mkdir -p "$backup_dir"
        cp -p "$key_file" "$backup_dir/"
        cp -p "$key_file.pub" "$backup_dir/" 2>/dev/null
        if [[ -f "$ssh_dir/config" ]]; then
            cp -p "$ssh_dir/config" "$backup_dir/"
        fi
        _ssh_green "Backup: $backup_dir"
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
        if [[ ! -f "$ssh_dir/config" ]]; then
            # No config exists — write a fresh one
            _ssh_blue "[STEP] Writing ~/.ssh/config..."

            cat > "$ssh_dir/config" <<'SSHEOF'
# SSH Client Configuration
# Generated by zsh-ssh-setup plugin
# Add your custom Host entries below.

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
            _ssh_green "Config created."

        elif [[ -n "$label" ]]; then
            # Named key — offer to add a Host block
            echo ""
            echo -n "Add a Host entry in ~/.ssh/config for this key? [y/N] "
            read -r add_host

            if [[ "$add_host" == [yY] ]]; then
                echo -n "Hostname or pattern (e.g. *.internal, 192.168.1.*): "
                read -r host_pattern

                if [[ -n "$host_pattern" ]]; then
                    cat >> "$ssh_dir/config" <<SSHEOF

# Added by ssh-gen ($key_comment)
Host $host_pattern
    IdentityFile $key_file
SSHEOF
                    _ssh_green "Host block added to ~/.ssh/config"
                fi
            fi
        else
            _ssh_yellow "~/.ssh/config already exists (not overwritten)"
            echo "  Use 'ssh-gen --no-config' to silence this, or edit manually."
        fi
    fi

    echo ""

    # --- Display public key ---
    _ssh_blue "[STEP] Your public key:"
    echo ""
    if [[ "$_SSH_IS_TTY" == true ]]; then
        _ssh_bold "═══════════════════════════════════════════════════════════"
    fi
    cat "$key_file.pub"
    if [[ "$_SSH_IS_TTY" == true ]]; then
        _ssh_bold "═══════════════════════════════════════════════════════════"
    fi
    echo ""

    _ssh_to_clipboard "$key_file.pub"

    echo ""

    # --- Deploy instructions ---
    _ssh_bold "Deploy your public key to:"
    echo ""
    echo "  GitHub:      https://github.com/settings/ssh/new"
    if command -v gh &>/dev/null; then
        echo "    or run:    gh ssh-key add $key_file.pub --title \"$key_comment\""
    fi
    echo ""
    echo "  GitLab:      https://gitlab.com/-/user_settings/ssh_keys"
    if command -v glab &>/dev/null; then
        echo "    or run:    glab ssh-key add $key_file.pub --title \"$key_comment\""
    fi
    echo ""
    echo "  Server:      ssh-deploy user@hostname${label:+ $label}"
    echo ""

    # --- Verify ---
    _ssh_blue "[STEP] Verification..."
    ssh-info ${label}

    if [[ "$_SSH_IS_TTY" == true ]]; then
        _ssh_bold "══════════════════════════════════════"
        _ssh_bold "  Done! Deploy your pubkey, then test:"
        _ssh_bold "    ssh-deploy user@host"
        _ssh_bold "══════════════════════════════════════"
    else
        _ssh_bold "Done! Deploy your pubkey, then test: ssh-deploy user@host"
    fi
    echo ""
}

# --- Aliases ---
alias ssg='ssh-gen'
alias ssp='ssh-pub'
alias ssi='ssh-info'
alias ssd='ssh-deploy'
alias ssf='ssh-fix-perms'
