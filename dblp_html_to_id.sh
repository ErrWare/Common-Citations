#!/bin/sh

# Extracts the article ids from a dblp query results webpage.
# Requires the `pup` html parsing command line tool.
#
# Usage:
#   wget <dblp_query_url> | dblp_html_to_id.sh

cat - | pup 'li[class="details"] a' | grep "^<a" | grep -o 'https:[^"]\+' | sed -n 's/.html$//p'
