# bash completion for minil
#
# minil-completion
# ================
#
# Bash completion support for [minil](https://github.com/tokuhirom/Minilla)
#
#
# Installation
# -------------
#
#  1. Install bash-completion
#
#  2. Install this file. Either:
#
#     a. Place it in a `bash-completion.d` folder:
#
#        * /etc/bash-completion.d
#        * /usr/local/etc/bash-completion.d
#        * ~/bash-completion.d
#
#        e.g.
#
#            $ cp this-file /etc/bash-completion.d/minil
#
#     b. Or, copy it somewhere (e.g. ~/.minil-completion.sh) and put the following line in
#        your .bashrc:
#
#            source ~/.minil-completion.sh

_minil()
{
  local subcommands cur
  _get_comp_words_by_ref cur
  subcommands="new build test clean dist install release migrate help"

  case "${COMP_WORDS[1]}" in
    new)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--profile --username --email --help'
      fi
      ;;
    build)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--help'
      fi
      ;;
    test)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--release --automated --author --all --help'
      fi
      ;;
    clean)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--help -y'
      fi
      ;;
    dist)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--help'
      fi
      ;;
    install)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--no-test --help'
      fi
      ;;
    release)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--no-test --trial --dry-run --pause-config --help'
      fi
      ;;
    migrate)
      subcommands=''
      if [[ "${cur}" == -* ]] ; then
        subcommands='--help'
      fi
      ;;
    help)
      return 0
      ;;
  esac
  COMPREPLY=($(compgen -W "${subcommands}" -- ${cur}))
}
complete -F _minil minil

# Local variables:
# mode: shell-script
# sh-basic-offset: 2
# sh-indent-comment: t
# indent-tabs-mode: nil
# End:
# ex: ts=2 sw=2 et filetype=sh
