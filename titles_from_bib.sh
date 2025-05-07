#!/bin/sh

# Extracts the titles from a bibtex bibliography.
#
# Usage:
#   titles_from_bib.sh path/to/bibliography.bib

BIBFILE="$1"

grep -w title "$BIBFILE" | sed 's/^[^{"]*[{"]//; s/[:/"].*$//' | tr -d '{}:,'
