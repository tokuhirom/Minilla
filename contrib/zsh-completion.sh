#compdef minil
# ------------------------------------------------------------------------------
# Description
# -----------
#
#  Completion script for minil (https://github.com/tokuhirom/Minilla).
#
# ------------------------------------------------------------------------------
# Authors
# -------
#
#  * tokuhirom (https://github.com/tokuhirom)
#  * syohex    (https://github.com/syohex)
#  * xaicron   (https://github.com/xaicron)
#
# ------------------------------------------------------------------------------
# Instllation
# ------------
#
#  Copy this file to your $fpath directory.
#  For example, if you fpath is ~/.zsh/fpath:
#
#    $ cp this-file ~/.zsh/fpath/_minil
#
#  You may have to force rebuild zcompdump:
#
#    $ rm -f ~/.zcompdump; compinit
#
# -------------------------------------------------------------------------------

_minil() {
  typeset -A opt_args
  local context state line

  local -a _minil_subcommands
  _minil_subcommands=(
    'new:Create a new dist'
    'build:Build distribution'
    'test:Run test cases'
    'clean:Clean up directory'
    'dist:Make dist tarball'
    'install:Install distribution'
    'release:Release distribution to CPAN'
    'migrate:Migrate existed distribution repo'
    'help:Help me'
  )

  _arguments '*:: :->subcmd'

  if [[ "$state" == "subcmd" ]];then

    if (( CURRENT == 1 )); then
      _describe -t commands "minil command" _minil_subcommands -V1
      return
    else
      local opts curcontext

      case "$words[1]" in
        new)
          opts=(
            '(--username)--username[Specifies Username]:username:'
            '(--email)--email[Specifies Email Address]:email:'
            '(-p|--profile)'{-p,--profile}'[Minilla profile]: :(XS)'
          )
          ;;
        install)
          opts=('--no-test[Do not run test]')
          ;;
        release)
          opts=(
            '--no-test[Do not run test]'
            '--trial[Trial release]'
            '--dry-test[Dry run mode]'
          )
          ;;
        test)
          opts=(
            '--release[enable the RELEASE_TESTING env variable]'
            '--automated[enable the AUTOMATED_TESTING env variable]'
            '--author[enable the AUTHOR_TESTING env variable]'
            '--all[enable the All env variables]'
          )
          ;;
        *)
          opts=()
          ;;
      esac
      _arguments -s : "$opts[@]" '*::Files:_files'
    fi
  fi
}
