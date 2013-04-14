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

compdef _minil minil

# Local Variables:
# mode: Shell-Script
# sh-indentation: 2
# indent-tabs-mode: nil
# sh-basic-offset: 2
# End:
# vim: ft=zsh sw=2 ts=2 et
