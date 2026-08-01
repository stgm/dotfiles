# work -- go to a repo from one of my GitHub orgs, cloning it into
# ~/dev/<org>/<repo> first if it isn't there yet
#
#   work progr          matching repos appear as you type, best match ghosted
#   <TAB>               move the selection down the list, <S-TAB> back up
#   <ENTER>             go to the suggestion on the line, tabbed to or not
#   work --refresh      refetch the repo list now
#
# At the prompt the suggestion is always visible before enter is pressed, so it
# is taken as the answer. Called with an ambiguous query from a script, where
# nothing was on screen to read, work refuses rather than guesses.
#
# The repo list is cached and refreshed in the background once a day, so typing
# never waits on the network (except on the very first use).

WORK_ORGS=(stgm minprog uvapl spcourse uva-sp uvaai)
WORK_ROOT=$HOME/dev
WORK_CACHE=$HOME/.cache/work-repos.txt
WORK_LIVE_MAX=${WORK_LIVE_MAX:-10}   # cap on the as-you-type list

# Fetch every repo of every org into the cache. Written via a temp file so a
# background refresh can't leave a half-written cache behind. The first line
# records which orgs it was built from, so editing WORK_ORGS invalidates it
# right away instead of a day later.
_work_refresh() {
    if ! command -v gh >/dev/null; then
        print -u2 "work: gh is not installed"
        return 1
    fi

    local tmp org
    tmp=$(mktemp) || return 1

    # An org that can't be listed (typo, no access, github down) is reported and
    # skipped rather than taken as a reason to throw the other orgs away. The
    # header still claims it, so the next scheduled refresh retries it.
    for org in $WORK_ORGS; do
        gh repo list "$org" --limit 1000 --json nameWithOwner,pushedAt \
            --jq '.[] | [.pushedAt, .nameWithOwner] | @tsv' >>$tmp ||
            print -u2 "work: could not list repositories for $org"
    done

    if [[ ! -s $tmp ]]; then
        print -u2 "work: no repositories found in: $WORK_ORGS"
        rm -f $tmp
        return 1
    fi

    # Most recently pushed first, across all the orgs at once -- gh only sorts
    # within one org. ISO-8601 timestamps sort correctly as plain text, so the
    # date is only carried along to sort on and then dropped.
    mkdir -p ${WORK_CACHE:h}
    if ! { print -r -- "#orgs $WORK_ORGS"; sort -r $tmp | cut -f2 } >$tmp.sorted; then
        rm -f $tmp $tmp.sorted
        return 1
    fi
    rm -f $tmp
    mv $tmp.sorted $WORK_CACHE
}

# True when the cache exists and was built from the orgs configured right now.
_work_cache_current() {
    [[ -r $WORK_CACHE ]] || return 1

    local header
    read -r header <$WORK_CACHE || return 1
    [[ $header == '#orgs '* ]] || return 1

    # Order doesn't matter, only which orgs are covered.
    [[ ${(j: :)${(o)${=header#\#orgs }}} == ${(j: :)${(o)WORK_ORGS}} ]]
}

# Print the cached repo list, fetching it first if it's unusable and kicking off
# a background refresh if it's over a day old.
_work_cache() {
    setopt localoptions extendedglob
    local -a fresh

    if ! _work_cache_current; then
        print -u2 "work: fetching repositories..."
        _work_refresh || return 1
    else
        # Empty unless the cache was modified less than 24 hours ago.
        fresh=($WORK_CACHE(#qNmh-24))
        (( $#fresh )) || (_work_refresh >/dev/null 2>&1 &)
    fi

    tail -n +2 $WORK_CACHE
}

# Rank the candidates in $2... against the query in $1, best first:
#
#   1. the repo name starts with the query      progr   -> minprog/programmeren-1
#   2. the query appears anywhere               ammeren -> minprog/programmeren-1
#   3. the query letters appear in order        prog-1  -> minprog/programmeren-1
#
# Within a tier the caller's order is kept, and the cache is written most
# recently pushed first, so the repo touched last wins. Sets $reply.
_work_filter() {
    setopt localoptions extendedglob
    local q=$1; shift
    local -a all=("$@") chars lead sub fuzzy
    local esc=${(b)q} pattern

    # "prog" becomes *p*r*o*g*, quoting each character so a repo name with a
    # dash or dot in it can't act as a glob.
    chars=(${(s::)q})
    pattern="*${(j:*:)${(@b)chars}}*"

    lead=(${(M)all:#(#i)*/${~esc}*})
    sub=(${(M)all:#(#i)*${~esc}*})
    fuzzy=(${(M)all:#(#i)${~pattern}})

    sub=(${sub:|lead})
    fuzzy=(${fuzzy:|lead})
    fuzzy=(${fuzzy:|sub})

    reply=($lead $sub $fuzzy)
}

work() {
    if [[ $1 == -r || $1 == --refresh ]]; then
        _work_refresh && print "work: cached $(wc -l <$WORK_CACHE | tr -d ' ') repositories"
        return
    fi

    setopt localoptions extendedglob
    local query=$1 choice
    local -a repos matches reply
    repos=(${(f)"$(_work_cache)"}) || return 1

    if [[ -z $query ]]; then
        print "usage: work <query>   (tab takes the best match)"
        print "\nrecent:"
        print -l "  "${^repos[1,5]}
        return 1
    fi

    _work_filter "$query" $repos
    matches=($reply)

    # An exact name wins outright, so `work stgm/course-site` goes there and
    # isn't held up by course-site-build also matching.
    local -a exact=(${(M)repos:#(#i)${(b)query}})

    if (( $#exact )); then
        choice=$exact[1]
    elif (( $#matches == 1 )); then
        choice=$matches[1]
    elif (( $#matches == 0 )) && [[ $query == */* ]]; then
        # Not in the cache -- maybe it's brand new. Try it anyway.
        choice=$query
    elif (( $#matches == 0 )); then
        print -u2 "work: '$query' is not a repository"
        return 1
    else
        # Deliberately no picker: the as-you-type list is already showing these,
        # and tab resolves it in one keystroke.
        print -u2 "work: '$query' is not a repository (matches $#matches, best '$matches[1]')"
        return 1
    fi

    local dest=$WORK_ROOT/$choice

    # Already there is the normal case, so it just goes; only an actual clone
    # is worth saying anything about, and git says it itself.
    if [[ ! -d $dest ]]; then
        mkdir -p ${dest:h}
        git clone git@github.com:$choice.git $dest || return 1
    fi

    cd $dest
}

##############################################################################
# The as-you-type list. Everything below only matters at the prompt, so it is
# skipped entirely when this file is sourced by a script.

if [[ -o interactive ]]; then

typeset -ga _work_live_repos
typeset -g _work_live_mtime= _work_live_last= _work_live_shown= _work_live_pick=
typeset -g _work_live_fetching=0

# The list tab is currently stepping through, and where in it we are (0 = tab
# hasn't been pressed since the query last changed).
typeset -ga _work_live_cycle
typeset -g _work_live_index=0

# Show $1 after the cursor in grey, or clear the suggestion when called with
# nothing. The greying is tagged with a memo so every entry we ever added can be
# taken back out again -- dropping only the last one leaves earlier ones behind,
# and a stale entry dims part of the real command once the line gets longer.
# Entries anything else put in region_highlight are left alone.
_work_live_ghost() {
    region_highlight=(${region_highlight:#*memo=work-ghost*})
    POSTDISPLAY=${1:-}
    [[ -z $POSTDISPLAY ]] && return
    region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=8 memo=work-ghost")
}

# Hold the cache in memory, re-reading it only when it actually changed, so a
# background refresh lands without needing a new shell.
_work_live_load() {
    # A cache that is missing or built from different orgs is rebuilt from here
    # too -- typing is usually the first thing to notice, and waiting for the
    # command to be run would leave the list empty until then. Kept in the
    # background so the keystroke doesn't block, and to one fetch at a time.
    if ! _work_cache_current; then
        if (( ! _work_live_fetching )); then
            _work_live_fetching=1
            (_work_refresh >/dev/null 2>&1 &)
        fi
    else
        _work_live_fetching=0
    fi

    [[ -r $WORK_CACHE ]] || return 1

    local -a st
    zmodload -F zsh/stat b:zstat 2>/dev/null && zstat -A st +mtime $WORK_CACHE
    if [[ $st[1] != $_work_live_mtime ]]; then
        _work_live_repos=(${${(f)"$(<$WORK_CACHE)"}[2,-1]})   # drop the #orgs line
        _work_live_mtime=$st[1]
    fi
    (( $#_work_live_repos ))
}

# Paint the match list under the prompt and the selection after the cursor,
# from the cycle that _work_live_redraw last built.
_work_live_render() {
    local -a reply=($_work_live_cycle)
    (( $#reply )) || return

    # Never take more than a third of the window, so a short terminal doesn't
    # turn into a wall of repos.
    local n=$(( LINES / 3 < WORK_LIVE_MAX ? LINES / 3 : WORK_LIVE_MAX ))
    (( n < 1 )) && n=1

    # Scroll the window along once tab has cycled past the bottom of it.
    local start=1
    (( _work_live_index > n )) && start=$(( _work_live_index - n + 1 ))
    local -a lines
    local i
    for (( i = start; i <= start + n - 1 && i <= $#reply; i++ )); do
        if (( i == _work_live_index )); then
            lines+=("> $reply[i]")
        else
            lines+=("  $reply[i]")
        fi
    done

    local extra="" left=$(( $#reply - (start + $#lines - 1) ))
    (( left > 0 )) && extra=$'\n'"  ...and $left more"
    (( start > 1 )) && extra+="   [$_work_live_index/$#reply]"
    zle -M "${(F)lines}$extra"
    _work_live_shown=1

    # Shown after the cursor rather than written onto the line, so what was
    # typed stays there and stays editable even after tab has been used.
    _work_live_pick=$reply[$(( _work_live_index ? _work_live_index : 1 ))]
    if [[ ${BUFFER#work } != $_work_live_pick ]]; then
        _work_live_ghost " -> $_work_live_pick"
    else
        _work_live_ghost
    fi
}

# Rebuild the match list whenever the line changes. Ranking comes from
# _work_filter, so the list, the selection and what work itself would pick can
# never disagree.
_work_live_redraw() {
    [[ $BUFFER == $_work_live_last ]] && return   # cursor moved, nothing typed
    _work_live_last=$BUFFER
    _work_live_ghost
    _work_live_pick=
    _work_live_cycle=()
    _work_live_index=0

    if [[ $BUFFER != work\ * ]]; then
        [[ -n $_work_live_shown ]] && { zle -M ""; _work_live_shown= }
        return
    fi

    # Say so rather than showing an empty space: the fetch kicked off by
    # _work_live_load lands within a keystroke or two.
    if ! _work_live_load; then
        zle -M "  (fetching repositories...)"
        _work_live_shown=1
        return
    fi

    local -a reply
    _work_filter "${BUFFER#work }" $_work_live_repos
    _work_live_cycle=($reply)

    if (( ! $#reply )); then
        zle -M "  (no match)"
        _work_live_shown=1
        return
    fi

    _work_live_render
}

# On a work line tab moves the selection down the list -- the only way to reach
# spcourse/sp1 when spcourse/sp101 outranks it -- without disturbing the query,
# so it can still be corrected afterwards. Elsewhere tab stays whatever it was
# bound to before.
_work_live_tab() {
    if [[ $BUFFER != work\ * ]]; then
        zle ${_work_live_tab_orig:-expand-or-complete}
        return
    fi
    (( $#_work_live_cycle )) || return
    (( _work_live_index = _work_live_index % $#_work_live_cycle + 1 ))
    _work_live_render
}

# Shift-tab walks back up the list.
_work_live_shift_tab() {
    [[ $BUFFER == work\ * ]] || return
    (( $#_work_live_cycle )) || return
    (( _work_live_index = (_work_live_index + $#_work_live_cycle - 2) % $#_work_live_cycle + 1 ))
    _work_live_render
}

# Right arrow at the end of the line writes the selection onto the line, for
# when it needs editing rather than running; anywhere else it just moves the
# cursor.
_work_live_forward_char() {
    if [[ -n $_work_live_pick ]] && (( CURSOR == ${#BUFFER} )); then
        BUFFER="work $_work_live_pick"
        CURSOR=${#BUFFER}
        _work_live_ghost
    else
        zle .forward-char
    fi
}

_work_live_accept_line() {
    # The suggestion was never written onto the line, so put it there now: it is
    # where we are actually going, and it is what history should record. This
    # takes the top match when tab was never pressed, which is safe because the
    # suggestion is right there on the line to be read before pressing enter.
    # An empty query is left alone, so a bare `work` still explains itself
    # instead of silently going to the most recently pushed repo.
    if [[ $BUFFER == work\ * && -n ${BUFFER#work } && -n $_work_live_pick ]]; then
        BUFFER="work $_work_live_pick"
        # Keep the pre-redraw hook from ghosting this rewritten line on its way
        # out, which would leave "-> ..." sitting in the scrollback.
        _work_live_last=$BUFFER
    fi

    # Both the suggestion and its greying-out have to go, or the accepted line
    # keeps a dim stretch where the ghost used to be.
    _work_live_ghost
    [[ -n $_work_live_shown ]] && { zle -M ""; _work_live_shown= }
    _work_live_cycle=()
    _work_live_index=0
    zle .accept-line
}

typeset -g _work_live_tab_orig=${${(z)"$(bindkey '^I')"}[2]}

zle -N zle-line-pre-redraw _work_live_redraw
zle -N forward-char _work_live_forward_char
zle -N accept-line _work_live_accept_line
zle -N _work_live_tab
zle -N _work_live_shift_tab
bindkey '^I' _work_live_tab
bindkey '^[[Z' _work_live_shift_tab

fi
