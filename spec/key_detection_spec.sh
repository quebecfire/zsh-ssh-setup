Describe '_ssh_find_all_private_keys()'
  Include spec/spec_helper.sh

  BeforeEach 'setup'
  AfterEach 'cleanup'

  It 'finds an ed25519 key'
    load_plugin
    create_ed25519_key "id_ed25519"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'finds an RSA key'
    load_plugin
    create_rsa_key "gitkraken_rsa"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'finds an ECDSA key'
    load_plugin
    create_ecdsa_key "id_ecdsa"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'finds multiple keys of different types'
    load_plugin
    create_ed25519_key "id_ed25519"
    create_rsa_key "gitkraken_rsa"
    create_ed25519_key "id_ed25519_work" "work"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 3
  End

  It 'ignores known_hosts file'
    load_plugin
    create_ed25519_key "id_ed25519"
    echo "github.com ssh-ed25519 AAAA..." > "$SSH_DIR/known_hosts"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'ignores config file'
    load_plugin
    create_ed25519_key "id_ed25519"
    echo "Host *" > "$SSH_DIR/config"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'ignores authorized_keys file'
    load_plugin
    create_ed25519_key "id_ed25519"
    cp "$SSH_DIR/id_ed25519.pub" "$SSH_DIR/authorized_keys"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'ignores .pub files and only returns private key'
    load_plugin
    create_ed25519_key "id_ed25519"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
    The value "${_SSH_PRIVATE_KEYS[1]}" should end with "id_ed25519"
  End

  It 'ignores backup-* files'
    load_plugin
    create_ed25519_key "id_ed25519"
    echo "-----BEGIN OPENSSH PRIVATE KEY-----" > "$SSH_DIR/backup-old"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'ignores empty files'
    load_plugin
    create_ed25519_key "id_ed25519"
    touch "$SSH_DIR/empty_file"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 1
  End

  It 'handles empty ~/.ssh/ gracefully'
    load_plugin
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 0
  End

  It 'handles missing ~/.ssh/ gracefully'
    load_plugin
    rmdir "$SSH_DIR"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 0
    The status should be success
  End

  It 'follows symlinks to private keys'
    load_plugin
    create_ed25519_key "id_ed25519"
    ln -s "$SSH_DIR/id_ed25519" "$SSH_DIR/my_symlink_key"
    When call _ssh_find_all_private_keys
    The value "${#_SSH_PRIVATE_KEYS[@]}" should eq 2
  End
End

Describe '_ssh_key_type()'
  Include spec/spec_helper.sh

  BeforeEach 'setup'
  AfterEach 'cleanup'

  It 'returns ED25519 for ed25519 key'
    load_plugin
    create_ed25519_key "id_ed25519"
    When call _ssh_key_type "$SSH_DIR/id_ed25519"
    The output should eq "ED25519"
  End

  It 'returns RSA for RSA key'
    load_plugin
    create_rsa_key "test_rsa"
    When call _ssh_key_type "$SSH_DIR/test_rsa"
    The output should eq "RSA"
  End

  It 'returns ECDSA for ECDSA key'
    load_plugin
    create_ecdsa_key "id_ecdsa"
    When call _ssh_key_type "$SSH_DIR/id_ecdsa"
    The output should eq "ECDSA"
  End

  It 'returns UNKNOWN for nonexistent file'
    load_plugin
    When call _ssh_key_type "$SSH_DIR/nonexistent"
    The output should eq "UNKNOWN"
    The status should be failure
  End
End

Describe '_ssh_is_managed_key()'
  Include spec/spec_helper.sh

  BeforeEach 'setup'
  AfterEach 'cleanup'

  It 'returns true for id_ed25519'
    load_plugin
    When call _ssh_is_managed_key "$SSH_DIR/id_ed25519"
    The status should be success
  End

  It 'returns true for id_ed25519_work'
    load_plugin
    When call _ssh_is_managed_key "$SSH_DIR/id_ed25519_work"
    The status should be success
  End

  It 'returns false for gitkraken_rsa'
    load_plugin
    When call _ssh_is_managed_key "$SSH_DIR/gitkraken_rsa"
    The status should be failure
  End

  It 'returns false for jzcommander_deploy'
    load_plugin
    When call _ssh_is_managed_key "$SSH_DIR/jzcommander_deploy"
    The status should be failure
  End

  It 'returns false for id_rsa'
    load_plugin
    When call _ssh_is_managed_key "$SSH_DIR/id_rsa"
    The status should be failure
  End
End
