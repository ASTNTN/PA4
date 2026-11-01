#!/bin/bash
# md-to-html-styled: thin wrapper delegating to the shared md-to-html skill.
# Was a full local copy of the script; now one shared implementation at
# ~/.claude/skills/md-to-html/ instead of one copy per project. Kept under
# this name/path so existing usage and muscle memory in this project keep
# working unchanged.
exec bash /s/bach/a/class/cs475/.claude/skills/md-to-html/md-to-html.sh "$@"
