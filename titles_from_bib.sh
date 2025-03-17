#!/bin/sh
# First arg is the bibliography in bibtex format
BIBFILE="$1"

grep -w title "$BIBFILE" | sed 's/^[^{"]*[{"]//; s/[:/"}].*$//'
