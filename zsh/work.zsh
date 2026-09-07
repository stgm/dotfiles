# work -- go to a repo from one of my GitHub orgs, cloning it into
# ~/dev/<org>/<repo> first if it isn't there yet
#
#   work progr          matching repos appear as you type, best match ghosted
#   <TAB>               move the selection down the list, <S-TAB> back up
#   <ENTER>             go to the suggestion on the line, tabbed to or not
#   work --refresh      refetch the repo list now
#   work -c org/repo [gh flags]
#                       create a new (public by default) repo on GitHub,
#                       clone it into place, and go there. No autocomplete
#                       here since the repo doesn't exist yet to match against
#
# At the prompt the suggestion is on screen before enter is pressed, so it is
# taken as the answer. From a script nothing is on screen, so an ambiguous
# query is an error instead of a guess.
#
# The repo list is cached and refreshed in the background once a day, so typing
# never waits on the network (except on the very first use).
#
# Arriving in a repo checks origin for new commits, also once a day per repo. If
# they can be fast-forwarded in it offers to do that, otherwise it just says how
# the branch stands.

WORK_ORGS=(stgm minprog uvapl spcourse uva-sp uvaai prgbas)
WORK_ROOT=$HOME/dev
WORK_CACHE=$HOME/.cache/work-repos.txt
WORK_LIVE_MAX=${WORK_LIVE_MAX:-10}   # cap on the as-you-type list

# Write every repo of every org to the cache. Built in a temp file so a
# background refresh can't leave a half-written cache behind. The first line
# lists the orgs it was built from, so editing WORK_ORGS invalidates it at once
# instead of a day later.
_work_refresh() {
    if ! command -v gh >/dev/null; then
        print -u2 "work: gh is not installed"
        return 1
    fi

    local tmp org
    tmp=$(mktemp) || return 1

    # An org that can't be listed (typo, no access, github down) is reported and
    # skipped; the others are still cached. The header still names it, so the
    # next refresh tries again.
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

    # Most recently pushed first, across all orgs at once -- gh only sorts
    # within one org. ISO-8601 timestamps sort correctly as text, so the date is
    # only there to sort on and is then dropped.
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

# Print the cached repo list. Fetches first if the cache is unusable, and starts
# a background refresh if it is over a day old.
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

# Remove the repo we are currently in from $@ -- going where we already are is
# never what was meant. The current repo is the first two path components under
# $WORK_ROOT, so this also works from a subdirectory. Sets $reply. Uses no
# subshell, because this runs on every keystroke.
_work_drop_here() {
    setopt localoptions extendedglob
    reply=("$@")

    local rel=${PWD#$WORK_ROOT/}
    [[ $rel != $PWD ]] || return

    local -a parts=(${(s:/:)rel})
    (( $#parts >= 2 )) || return

    reply=(${reply:#(#i)${(b)parts[1]}/${(b)parts[2]}})
}

# Sort the candidates in $2... by how well they match the query in $1:
#
#   1. the repo name starts with the query      progr   -> minprog/programmeren-1
#   2. the query appears anywhere               ammeren -> minprog/programmeren-1
#   3. the query letters appear in order        prog-1  -> minprog/programmeren-1
#
# Within a tier the caller's order is kept, and the cache is most recently
# pushed first, so the repo touched last wins. Sets $reply.
_work_filter() {
    setopt localoptions extendedglob
    local q=$1; shift
    local -a all=("$@") chars lead sub fuzzy
    local esc=${(b)q} pattern

    # "prog" becomes *p*r*o*g*, with each character quoted so a dash or dot in a
    # repo name can't act as a glob.
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

# Create a new repo on GitHub, clone it straight into $WORK_ROOT/<org>/<repo>,
# and go there. Extra args pass through to `gh repo create` (e.g.
# --description, --private), so the only thing supplied here is a --public
# default when the caller didn't say --public/--private/--internal.
_work_create() {
    if [[ -z $1 || $1 == -* ]]; then
        print -u2 "usage: work -c <org>/<repo> [gh repo create flags]"
        return 1
    fi
    if ! command -v gh >/dev/null; then
        print -u2 "work: gh is not installed"
        return 1
    fi

    local name=$1; shift
    if [[ $name != */* ]]; then
        print -u2 "work: '$name' needs an org, e.g. stgm/$name"
        return 1
    fi

    local org=${name%%/*} repo=${name#*/}
    (( ${WORK_ORGS[(Ie)$org]} )) || {
        print -u2 "work: '$org' is not in \$WORK_ORGS ($WORK_ORGS)"
        return 1
    }

    local dest=$WORK_ROOT/$org/$repo
    if [[ -d $dest ]]; then
        print -u2 "work: $dest already exists"
        return 1
    fi

    local -a flags=("$@")
    local f has_vis=0
    for f in $flags; do
        [[ $f == --public || $f == --private || $f == --internal ]] && has_vis=1
    done
    (( has_vis )) || flags+=(--public)

    # gh clones into ./<repo>, so run it from the org directory to land
    # straight in $dest instead of somewhere we'd have to move it from.
    mkdir -p $WORK_ROOT/$org
    (cd $WORK_ROOT/$org && gh repo create "$name" --clone $flags) || return 1

    # A fresh clone is up to date by definition, same as a plain `work` clone.
    touch $dest/.git/work-last-fetch
    cd $dest || return 1

    # The new repo won't be in the cache yet; pick it up for next time without
    # making this command wait on a full org listing.
    (_work_refresh >/dev/null 2>&1 &)
}

work() {
    if [[ $1 == -r || $1 == --refresh ]]; then
        _work_refresh && print "work: cached $(wc -l <$WORK_CACHE | tr -d ' ') repositories"
        return
    fi

    if [[ $1 == -c ]]; then
        _work_create "${@:2}"
        return
    fi

    setopt localoptions extendedglob
    local query=$1 choice
    local -a repos candidates matches reply
    repos=(${(f)"$(_work_cache)"}) || return 1

    # Ranking and the recent list skip the repo we are in. The exact match below
    # still uses the whole cache, so naming it outright is not an error.
    _work_drop_here $repos
    candidates=($reply)

    if [[ -z $query ]]; then
        print "usage: work <query>   (tab takes the best match)"
        print "\nrecent:"
        print -l "  "${^candidates[1,5]}
        return 1
    fi

    _work_filter "$query" $candidates
    matches=($reply)

    # An exact name wins outright, so `work stgm/course-site` goes there even
    # though course-site-build also matches.
    local -a exact=(${(M)repos:#(#i)${(b)query}})

    if (( $#exact )); then
        choice=$exact[1]
    elif (( $#matches == 1 )); then
        choice=$matches[1]
    elif (( $#matches == 0 )) && [[ $query == */* ]]; then
        # Not in the cache -- maybe it is brand new. Try it anyway.
        choice=$query
    elif (( $#matches == 0 )); then
        print -u2 "work: '$query' is not a repository"
        return 1
    else
        # No picker on purpose: the as-you-type list already shows these, and
        # tab picks one in a single keystroke.
        print -u2 "work: '$query' is not a repository (matches $#matches, best '$matches[1]')"
        return 1
    fi

    local dest=$WORK_ROOT/$choice

    # Already cloned is the normal case, so it just goes. Only a real clone is
    # worth saying anything about, and git says it itself.
    if [[ ! -d $dest ]]; then
        mkdir -p ${dest:h}
        git clone git@github.com:$choice.git $dest || return 1
        # A fresh clone is up to date by definition, so start the day's clock
        # here instead of fetching again a second later.
        touch $dest/.git/work-last-fetch
    fi

    cd $dest || return 1
    _work_check_upstream
}

# Say so when origin has commits we don't have, and fast-forward on request.
# Runs at most once a day per repo, tracked by the mtime of a stamp file in the
# repo's own .git directory -- it costs a network round trip, and paying that on
# every work would make a command that is otherwise instant feel slow.
#
# This runs after the cd, so a slow or failing check never stops you getting to
# the repo. The fetch has to be synchronous because the question below needs its
# answer, so it says what it is waiting for while it runs.
#
# Only a fast-forward is offered. With local commits of your own, rebase or
# merge is a real decision and belongs to you; this only reports.
_work_check_upstream() {
    # Sourced by scripts as well, and a script must not stop on a question.
    [[ -o interactive ]] || return 0

    setopt localoptions extendedglob
    local gitdir stamp behind ahead answer
    local -a fresh

    gitdir=$(git rev-parse --git-dir 2>/dev/null) || return 0

    stamp=$gitdir/work-last-fetch
    fresh=($stamp(#qNmh-24))
    (( $#fresh )) && return 0

    # No upstream branch (detached head, a branch never pushed) means there is
    # nothing to compare against.
    git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || return 0

    print -n "checking for upstream changes..."
    git fetch --quiet 2>/dev/null
    local fetched=$?
    print -n "\r\e[K"

    if (( fetched )); then
        print -u2 "failed to check origin status"
        return 0
    fi

    touch $stamp

    # One call gives both counts: commits only they have, then only we have.
    IFS=$'\t' read -r behind ahead < <(git rev-list --count --left-right @{u}...HEAD)
    (( behind )) || return 0

    local news="$behind new commit${${behind:#1}:+s} at origin"

    if (( ahead )); then
        print "$news, diverged from local commits"
        return 0
    fi

    # Untracked files can't be in the way of a fast-forward, so they don't count
    # as a reason to hold back.
    if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
        print "$news, but uncommitted changes present"
        return 0
    fi

    # read -q would take anything but y as no; this one defaults to yes.
    read "answer?$news, fast-forward? [Y/n] "
    [[ -z $answer || $answer == [yY]* ]] || return 0

    git merge --ff-only @{u}
}

##############################################################################
# The as-you-type list. Everything below only applies at the prompt, so it is
# skipped when this file is sourced by a script.

if [[ -o interactive ]]; then

typeset -ga _work_live_repos
typeset -g _work_live_mtime= _work_live_last= _work_live_shown= _work_live_pick=
typeset -g _work_live_fetching=0

# The list tab steps through, and where in it we are (0 = tab has not been
# pressed since the query last changed).
typeset -ga _work_live_cycle
typeset -g _work_live_index=0

# Show $1 after the cursor in grey, or clear the suggestion when called with
# nothing. Each grey range is tagged with a memo so all of them can be removed
# again: removing only the last one leaves older ones behind, and a stale range
# dims part of the real command once the line grows. Ranges added by anything
# else are left alone.
_work_live_ghost() {
    region_highlight=(${region_highlight:#*memo=work-ghost*})
    POSTDISPLAY=${1:-}
    [[ -z $POSTDISPLAY ]] && return
    region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=8 memo=work-ghost")
}

# Keep the cache in memory, re-reading it only when it changed, so a background
# refresh shows up without starting a new shell.
_work_live_load() {
    # A cache that is missing or built from other orgs is rebuilt here too:
    # typing usually notices first, and waiting for the command to run would
    # leave the list empty until then. In the background so the keystroke does
    # not block, and one fetch at a time.
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

# Draw the match list under the prompt and the selection after the cursor, from
# the list _work_live_redraw last built.
_work_live_render() {
    local -a reply=($_work_live_cycle)
    (( $#reply )) || return

    # At most a third of the window, so a short terminal does not fill up with
    # repos.
    local n=$(( LINES / 3 < WORK_LIVE_MAX ? LINES / 3 : WORK_LIVE_MAX ))
    (( n < 1 )) && n=1

    # Scroll along once tab has moved past the bottom of the window.
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

    # Shown after the cursor instead of written onto the line, so what was typed
    # stays there and stays editable even after tab has been used.
    _work_live_pick=$reply[$(( _work_live_index ? _work_live_index : 1 ))]
    if [[ ${BUFFER#work } != $_work_live_pick ]]; then
        _work_live_ghost " -> $_work_live_pick"
    else
        _work_live_ghost
    fi
}

# Rebuild the match list whenever the line changes. The ranking comes from
# _work_filter, so the list, the selection and what work itself picks always
# agree.
_work_live_redraw() {
    [[ $BUFFER == $_work_live_last ]] && return   # cursor moved, nothing typed
    _work_live_last=$BUFFER
    _work_live_ghost
    _work_live_pick=
    _work_live_cycle=()
    _work_live_index=0

    if [[ $BUFFER != work\ * || $BUFFER == work\ -c* ]]; then
        [[ -n $_work_live_shown ]] && { zle -M ""; _work_live_shown= }
        return
    fi

    # Say so instead of showing nothing: the fetch started by _work_live_load
    # arrives within a keystroke or two.
    if ! _work_live_load; then
        zle -M "  (fetching repositories...)"
        _work_live_shown=1
        return
    fi

    local -a reply
    _work_drop_here $_work_live_repos
    _work_filter "${BUFFER#work }" $reply
    _work_live_cycle=($reply)

    if (( ! $#reply )); then
        zle -M "  (no match)"
        _work_live_shown=1
        return
    fi

    _work_live_render
}

# On a work line tab moves the selection down the list -- the only way to reach
# spcourse/sp1 when spcourse/sp101 ranks above it -- and leaves the query alone
# so it can still be corrected. Elsewhere tab does whatever it did before.
_work_live_tab() {
    if [[ $BUFFER != work\ * ]]; then
        zle ${_work_live_tab_orig:-expand-or-complete}
        return
    fi
    (( $#_work_live_cycle )) || return
    (( _work_live_index = _work_live_index % $#_work_live_cycle + 1 ))
    _work_live_render
}

# Shift-tab moves back up the list.
_work_live_shift_tab() {
    [[ $BUFFER == work\ * ]] || return
    (( $#_work_live_cycle )) || return
    (( _work_live_index = (_work_live_index + $#_work_live_cycle - 2) % $#_work_live_cycle + 1 ))
    _work_live_render
}

# Right arrow at the end of the line writes the selection onto the line, for
# when it needs editing instead of running. Anywhere else it just moves the
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
    # The suggestion was never on the line, so put it there now: it is where we
    # are going, and it is what history should record. Without tab this takes
    # the top match, which is safe because the suggestion was on screen to read.
    # `work ` with nothing after it counts too: the list is up and the first
    # entry is ghosted. A bare `work` never gets a suggestion, so it still
    # prints the usage.
    if [[ $BUFFER == work\ * && -n $_work_live_pick ]]; then
        BUFFER="work $_work_live_pick"
        # Stop the pre-redraw hook from ghosting this rewritten line on its way
        # out, which would leave "-> ..." in the scrollback.
        _work_live_last=$BUFFER
    fi

    # The suggestion and its grey range both have to go, or the accepted line
    # keeps a dim stretch where the ghost was.
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
