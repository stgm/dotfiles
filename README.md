# dotfiles

Personal Mac bootstrap: shell/git/ssh config, Homebrew packages, macOS defaults,
and setup of the `course-site` project.

## Install script

Download first, then run. The script prompts for a few things (Homebrew, the
SSH key passphrase, the course-site credentials key), so it needs a real
terminal on stdin -- piping it straight into `bash` breaks those prompts.

```bash
curl -fsSLo /tmp/install.sh https://raw.githubusercontent.com/stgm/dotfiles/main/install.sh && bash /tmp/install.sh
```

Or, if already cloned:

```bash
./install.sh
```

## The **work** command

`work` takes you to a repo from `stgm`, `minprog` or `uvapl`, cloning it into
`~/dev/<org>/<repo>` first if it isn't there yet.

```
work progr          matching repos are listed as you type, best one ghosted
<ENTER>             go to the suggestion shown after the arrow
<TAB>               move the selection down the list, <S-TAB> back up
<RIGHT>             write the selection onto the line, to edit it first
work --refresh      refetch the repo list now
```

The query matches on the repo name first, then anywhere in `org/repo`, and
finally on letters in order, so `prog-1` finds `minprog/programmeren-1` and
`crssite` finds `stgm/course-site`. Ties go to whichever repo was pushed to most
recently. An exact `org/repo` is taken as-is.

Tab is how you reach a repo the ranking puts second, like `spcourse/sp1` when
`spcourse/sp101` sits above it. It moves the marked line and the suggestion
after the cursor without touching what was typed, so the query can still be
corrected afterwards; the list scrolls once the selection passes the bottom of
it.

Enter goes to whatever the suggestion currently reads, tabbed to or not, and
writes it onto the line so history records the repo rather than the query. Run
from a script, where there was no suggestion to read, `work` refuses an
ambiguous query instead of guessing. A repo that is already cloned is just cd'd
into, without comment.

The list of repos comes from `gh` and is cached in `~/.cache/work-repos.txt`,
newest-first, refreshed in the background once a day. The cache records the orgs
it was built from on its first line, so editing `WORK_ORGS` rebuilds it at once
rather than a day later, and deleting the file just refills it. An org that
can't be listed is reported and skipped, leaving the others usable. Set `WORK_LIVE_MAX` to
cap how many matches the live list shows (default 10, never more than a third
of the window).
