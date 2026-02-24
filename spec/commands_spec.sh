Describe 'Public commands'
  Include spec/spec_helper.sh

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe 'ssh-gen'
    It 'creates named key and verifies comment format'
      load_plugin
      When call ssh-gen work --no-passphrase --no-config --force
      The status should be success
      The output should include "Key generated"
      The path "$SSH_DIR/id_ed25519_work" should be file
      The path "$SSH_DIR/id_ed25519_work.pub" should be file
    End

    It 'comment contains :work suffix in pub file'
      load_plugin
      ssh-gen work --no-passphrase --no-config --force >/dev/null 2>&1
      When call cat "$SSH_DIR/id_ed25519_work.pub"
      The output should include ":work"
    End

    It 'backs up existing key before replacing'
      load_plugin
      create_ed25519_key "id_ed25519_mykey" "mykey"
      When call ssh-gen mykey --no-passphrase --no-config --force
      The status should be success
      The output should include "Backup"
    End

    It '--help shows usage and exits 0'
      load_plugin
      When call ssh-gen --help
      The status should be success
      The output should include "Usage:"
      The output should include "--no-passphrase"
    End

    It 'rejects unknown option'
      load_plugin
      When call ssh-gen --bogus
      The status should be failure
      The output should include "Unknown option"
    End

    It 'creates ~/.ssh if it does not exist'
      load_plugin
      rmdir "$SSH_DIR"
      When call ssh-gen newkey --no-passphrase --no-config --force
      The status should be success
      The output should include "Created"
      The path "$SSH_DIR" should be directory
      The path "$SSH_DIR/id_ed25519_newkey" should be file
    End

    It 'creates ~/.ssh/config when it does not exist'
      load_plugin
      When call ssh-gen configtest --no-passphrase --force
      The status should be success
      The output should include "Config created"
      The path "$SSH_DIR/config" should be file
    End

    It 'sets correct permissions on generated key'
      load_plugin
      ssh-gen permtest --no-passphrase --no-config --force >/dev/null 2>&1
      When call stat -c %a "$SSH_DIR/id_ed25519_permtest"
      The output should eq "600"
    End
  End

  Describe 'ssh-pub'
    It 'outputs the public key content'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-pub
      The output should include "ssh-ed25519"
    End

    It 'ssh-pub --all lists all key types'
      load_plugin
      create_ed25519_key "id_ed25519"
      create_rsa_key "gitkraken_rsa"
      When call ssh-pub --all
      The output should include "ssh-ed25519"
      The output should include "ssh-rsa"
    End

    It 'ssh-pub --all shows key type labels'
      load_plugin
      create_ed25519_key "id_ed25519"
      create_rsa_key "gitkraken_rsa"
      When call ssh-pub --all
      The output should include "[default]"
      The output should include "[gitkraken_rsa]"
    End

    It 'returns error for nonexistent label'
      load_plugin
      When call ssh-pub nonexistent
      The status should be failure
      The output should include "No public key found"
    End

    It 'shows available keys when no default but named keys exist'
      load_plugin
      create_ed25519_key "id_ed25519_work" "work"
      When call ssh-pub
      The output should include "No default key"
      The output should include "Available keys"
    End

    It 'ssh-pub --all with no keys shows error'
      load_plugin
      When call ssh-pub --all
      The output should include "No SSH keys found"
    End
  End

  Describe 'ssh-info'
    It 'shows all keys grouped (managed vs other)'
      load_plugin
      create_ed25519_key "id_ed25519"
      create_rsa_key "gitkraken_rsa"
      When call ssh-info
      The output should include "Managed keys"
      The output should include "Other keys"
    End

    It 'resolves non-ed25519 key by literal name'
      load_plugin
      create_rsa_key "gitkraken_rsa"
      When call ssh-info gitkraken_rsa
      The output should include "gitkraken_rsa"
      The output should include "RSA"
    End

    It 'resolves managed key by label'
      load_plugin
      create_ed25519_key "id_ed25519_work" "work"
      When call ssh-info work
      The output should include "id_ed25519_work"
    End

    It 'returns error for nonexistent key'
      load_plugin
      When call ssh-info nonexistent
      The status should be failure
      The output should include "Key not found"
    End

    It 'shows no keys message when ~/.ssh is empty'
      load_plugin
      When call ssh-info
      The output should include "No SSH keys found"
    End
  End

  Describe 'ssh-deploy'
    It 'shows usage when called without args'
      load_plugin
      When call ssh-deploy
      The output should include "Usage:"
      The status should be failure
    End

    It 'returns error when key does not exist'
      load_plugin
      When call ssh-deploy user@host nonexistent
      The status should be failure
      The output should include "No public key found"
    End
  End

  Describe '_ssh_resolve_key'
    It 'returns default key path when no label'
      load_plugin
      When call _ssh_resolve_key
      The output should end with ".ssh/id_ed25519"
    End

    It 'returns named key path with label'
      load_plugin
      When call _ssh_resolve_key work
      The output should end with ".ssh/id_ed25519_work"
    End
  End

  Describe '_ssh_build_comment'
    It 'returns user@hostname-YYYY without label'
      load_plugin
      When call _ssh_build_comment
      The output should match pattern "*@*-20*"
    End

    It 'returns user@hostname-YYYY:label with label'
      load_plugin
      When call _ssh_build_comment work
      The output should include ":work"
      The output should match pattern "*@*-20*:work"
    End
  End

  Describe 'Aliases'
    It 'defines ssg alias'
      load_plugin
      When call type ssg
      The output should include "ssh-gen"
    End

    It 'defines ssp alias'
      load_plugin
      When call type ssp
      The output should include "ssh-pub"
    End

    It 'defines ssi alias'
      load_plugin
      When call type ssi
      The output should include "ssh-info"
    End

    It 'defines ssd alias'
      load_plugin
      When call type ssd
      The output should include "ssh-deploy"
    End

    It 'defines ssf alias'
      load_plugin
      When call type ssf
      The output should include "ssh-fix-perms"
    End
  End
End
