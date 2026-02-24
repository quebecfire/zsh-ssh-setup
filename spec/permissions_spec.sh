Describe 'Permission checks'
  Include spec/spec_helper.sh

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe 'ssh-info permissions'
    It 'reports OK for correct permissions (700, 600, 644)'
      load_plugin
      create_ed25519_key "id_ed25519"
      chmod 700 "$SSH_DIR"
      chmod 600 "$SSH_DIR/id_ed25519"
      chmod 644 "$SSH_DIR/id_ed25519.pub"
      When call ssh-info
      The output should include "✓"
      The output should include "All checks passed"
    End

    It 'reports error for world-readable private key'
      load_plugin
      create_ed25519_key "id_ed25519"
      chmod 644 "$SSH_DIR/id_ed25519"
      When call ssh-info
      The output should include "✗"
      The output should include "should be 600"
    End

    It 'checks permissions on non-ed25519 keys'
      load_plugin
      create_rsa_key "gitkraken_rsa"
      chmod 644 "$SSH_DIR/gitkraken_rsa"
      When call ssh-info
      The output should include "✗"
      The output should include "gitkraken_rsa"
      The output should include "should be 600"
    End

    It 'reports error for wrong ~/.ssh/ directory permissions'
      load_plugin
      create_ed25519_key "id_ed25519"
      chmod 755 "$SSH_DIR"
      When call ssh-info
      The output should include "✗"
      The output should include "should be 700"
    End

    It 'reports error for wrong config permissions'
      load_plugin
      create_ed25519_key "id_ed25519"
      echo "Host *" > "$SSH_DIR/config"
      chmod 644 "$SSH_DIR/config"
      When call ssh-info
      The output should include "✗"
      The output should include "should be 600"
    End
  End

  Describe 'ssh-fix-perms'
    It 'fixes incorrect permissions on all key types'
      load_plugin
      create_ed25519_key "id_ed25519"
      create_rsa_key "gitkraken_rsa"
      create_ed25519_key "id_ed25519_work" "work"
      chmod 644 "$SSH_DIR/id_ed25519"
      chmod 755 "$SSH_DIR/gitkraken_rsa"
      chmod 666 "$SSH_DIR/id_ed25519_work"
      When call ssh-fix-perms
      The status should be success
      The output should include "Done"
      Assert [ "$(stat -c %a "$SSH_DIR/id_ed25519")" = "600" ]
      Assert [ "$(stat -c %a "$SSH_DIR/gitkraken_rsa")" = "600" ]
      Assert [ "$(stat -c %a "$SSH_DIR/id_ed25519_work")" = "600" ]
    End

    It 'sets 644 on public keys'
      load_plugin
      create_ed25519_key "id_ed25519"
      chmod 600 "$SSH_DIR/id_ed25519.pub"
      When call ssh-fix-perms
      The status should be success
      The output should include "Done"
      Assert [ "$(stat -c %a "$SSH_DIR/id_ed25519.pub")" = "644" ]
    End

    It 'fixes ~/.ssh/ directory to 700'
      load_plugin
      chmod 755 "$SSH_DIR"
      When call ssh-fix-perms
      The status should be success
      The output should include "Done"
      Assert [ "$(stat -c %a "$SSH_DIR")" = "700" ]
    End

    It 'fixes config file to 600'
      load_plugin
      echo "Host *" > "$SSH_DIR/config"
      chmod 644 "$SSH_DIR/config"
      When call ssh-fix-perms
      The status should be success
      The output should include "Done"
      Assert [ "$(stat -c %a "$SSH_DIR/config")" = "600" ]
    End

    It 'fixes known_hosts to 644'
      load_plugin
      echo "github.com ssh-ed25519 AAAA..." > "$SSH_DIR/known_hosts"
      chmod 600 "$SSH_DIR/known_hosts"
      When call ssh-fix-perms
      The status should be success
      The output should include "Done"
      Assert [ "$(stat -c %a "$SSH_DIR/known_hosts")" = "644" ]
    End

    It 'returns error when ~/.ssh/ does not exist'
      load_plugin
      rmdir "$SSH_DIR"
      When call ssh-fix-perms
      The status should be failure
      The output should include "not found"
    End

    It 'handles empty ~/.ssh/ without errors'
      load_plugin
      When call ssh-fix-perms
      The status should be success
      The output should include "Done"
    End
  End
End
