_minil() {
    local -a cmds
    if (( CURRENT == 2 )); then
        # \ls lib/Minilla/CLI/*|perl -pe 's!.*/!!;s!\.pm!!;tr/A-Z/a-z/'
        compadd build clean dist help install migrate new release test
    fi

    return 1;
}

compdef _minil minil
