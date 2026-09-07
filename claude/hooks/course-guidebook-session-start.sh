#!/bin/bash
# SessionStart hook: if the cwd looks like a course repo (a grading.yml
# anywhere in the tree), load the grading guidebook from the course-site
# checkout (course repos don't carry the guidebook themselves; it lives
# in doc/final_grades.md of the course-site platform repo).
# Registered in ~/.claude/settings.json.

COURSE_SITE_GUIDE="${COURSE_SITE_GUIDEBOOK:-$HOME/dev/stgm/course-site/doc/final_grades.md}"

# Only ever scan inside an actual git checkout, and only from its root down.
# Without this guard, a session started from $HOME or a cloud-sync folder
# (OneDrive, SurfDrive, iCloud Drive) sends `find` straight into other
# apps' sandboxed data, which is what triggers the macOS "wants to access
# files from other programs" prompt.
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$repo_root" ] && exit 0

grading_file=$(find "$repo_root" -maxdepth 6 \
    \( -path "*/node_modules" -o -path "*/.git" -o -path "*/vendor" -o -path "*/tmp" -o -path "*/log" \) -prune \
    -o -iname "grading.yml" -print 2>/dev/null | head -1)

[ -z "$grading_file" ] && exit 0

# already inside the course-site repo itself: the guidebook is a normal
# file here, no need to inject it
[ -f "$repo_root/doc/final_grades.md" ] && exit 0

[ -f "$COURSE_SITE_GUIDE" ] || exit 0

content=$(cat "$COURSE_SITE_GUIDE")

jq -n --arg content "$content" --arg grading "$grading_file" --arg guide "$COURSE_SITE_GUIDE" '{
    hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: ("This looks like a course repo (found " + $grading + "). Loaded the grading guidebook from the course-site checkout (" + $guide + "), which describes how grading.yml controls final-grade calculation:\n\n" + $content)
    }
}'
