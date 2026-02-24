Describe 'Pipe-friendly output'
  Include spec/spec_helper.sh

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe 'Color functions'
    It '_ssh_red outputs plain text when _SSH_IS_TTY is false'
      load_plugin
      _SSH_IS_TTY=false
      When call _ssh_red "error message"
      The output should eq "error message"
    End

    It '_ssh_red outputs ANSI when _SSH_IS_TTY is true'
      load_plugin
      _SSH_IS_TTY=true
      When call _ssh_red "error message"
      The output should include $'\033['
      The output should include "error message"
    End

    It '_ssh_bold outputs plain text when _SSH_IS_TTY is false'
      load_plugin
      _SSH_IS_TTY=false
      When call _ssh_bold "title"
      The output should eq "title"
    End
  End

  Describe '_ssh_strip_output_args'
    It 'removes --plain from args'
      load_plugin
      When call _ssh_strip_output_args --plain work
      The value "${_SSH_ARGS[*]}" should eq "work"
    End

    It 'removes --color from args'
      load_plugin
      When call _ssh_strip_output_args --color work
      The value "${_SSH_ARGS[*]}" should eq "work"
    End

    It 'removes both --plain and --color'
      load_plugin
      When call _ssh_strip_output_args --plain --color work
      The value "${_SSH_ARGS[*]}" should eq "work"
    End

    It 'passes through args with no output flags'
      load_plugin
      When call _ssh_strip_output_args work --force
      The value "${_SSH_ARGS[*]}" should eq "work --force"
    End
  End

  Describe 'ANSI escape detection'
    It 'piped ssh-info output contains no ANSI escape sequences'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-info
      The output should not include $'\033['
    End

    It 'piped ssh-pub --all output contains no ANSI escape sequences'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-pub --all
      The output should not include $'\033['
    End

    It 'piped ssh-fix-perms output contains no ANSI escape sequences'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-fix-perms
      The output should not include $'\033['
    End
  End

  Describe '--plain flag'
    It '--color --plain results in plain output (last wins)'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-info --color --plain
      The output should not include $'\033['
    End

    It '--plain works on ssh-pub'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-pub --plain
      The output should not include $'\033['
    End

    It '--plain works on ssh-fix-perms'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-fix-perms --plain
      The output should not include $'\033['
    End
  End

  Describe '--color flag'
    It 'forces colored output on ssh-info'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-info --color
      The output should include $'\033['
    End

    It 'forces colored output on ssh-pub'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-pub --color
      The output should include $'\033['
    End

    It '--plain --color results in colored output (last wins)'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-info --plain --color
      The output should include $'\033['
    End
  End

  Describe '_ssh_to_clipboard() skip in pipe mode'
    It 'is skipped when _SSH_IS_TTY is false'
      load_plugin
      _SSH_IS_TTY=false
      When call _ssh_to_clipboard "/dev/null"
      The status should be success
      The output should eq ""
    End
  End

  Describe 'Decorative borders'
    It 'ssh-info has no decorative borders in pipe mode'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-info
      The output should not include "════"
    End

    It 'ssh-pub has no decorative borders in pipe mode'
      load_plugin
      create_ed25519_key "id_ed25519"
      When call ssh-pub
      The output should not include "════"
    End
  End
End
