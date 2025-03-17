#!/bin/zsh

# Input:
#   $1 - bibtex file
#   $2 - minimum number of citations for a result.
# Output:
#   TSV of query

BIBFILE="$1"

# This ${PARAM:-DEFAULT} evaluates to the default if PARAM is unset or the empty string,
# otherwise it evaluates to the value of PARAM.
MIN_CITATIONS="${2:-0}"
# Use this mirror when DBLP is getting DDoSed
DBLP_SITE="https://dblp.uni-trier.de/search"
#DBLP_SITE="https://dblp.org/search"

declare -a dblp_ids

echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Building Query From Bibliography                              -'
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# for title in "$(./titles_from_bib.sh "$1")"; do
./titles_from_bib.sh "$1" | while read title; do
  # Get at most 20 results from each title-based query.
  # Maybe this should be even less. A title should be quite specific.
  echo $title
  ID_FILE=".cache/${title// /_}.ids"
  [[ ! -f "$ID_FILE" ]] && \
    id_lines="$(curl -G --data-urlencode "q=$title" "$DBLP_SITE" | ./dblp_html_to_id.sh | head -n 20)" && \
    echo "$id_lines" > "$ID_FILE"
  num_results="$(cat "$ID_FILE" | tr ' ' '\n' | wc -l)"
  echo $num_results results for query "\"$title\""
  x=0
  for id in $(cat "$ID_FILE"); do
    dblp_ids+="<$id> "
    echo $x : $id
    x=$((x + 1))
  done
done

QUERYFILE="${BIBFILE// /}.sparql"
template='''
PREFIX cito: <http://purl.org/spar/cito/>
PREFIX dblp: <https://dblp.org/rdf/schema#>
PREFIX schema: <https://schema.org/>
PREFIX dct: <http://purl.org/dc/terms/>
SELECT ?CitedNode 
(IF(BOUND(?CitedTitleDblp),?CitedTitleDblp,?CitedTitleCito) AS ?CitedTitle)
?URL
(COUNT(DISTINCT ?GivenNode) AS ?N)
(REPLACE(GROUP_CONCAT(DISTINCT ?Title ; SEPARATOR=", "), ".,", ",") AS ?Citers)
WHERE {
  Values ?GivenNode {
  # <dblp_id> list
  PLACEHOLDER
  }.
  ?GivenNode dblp:title ?Title.
  ?GivenNode dblp:omid ?GottenNode .
  ?citation cito:hasCitingEntity ?GottenNode .
  ?citation cito:hasCitedEntity ?CitedNode .
  ?CitedNode schema:url ?URL
  Optional {
  ?DblpCitation dblp:omid ?CitedNode .
  ?DblpCitation dblp:title ?CitedTitleDblp. }
  
  SERVICE <https://opencitations.net/meta/sparql> {
    OPTIONAL { ?CitedNode dct:title ?CitedTitleCito .}
  }
}
GROUP BY ?CitedNode ?CitedTitleDblp ?CitedTitleCito ?URL
HAVING (?N >= MIN_CITATIONS)
ORDER BY DESC(?N)
'''

# Log the query for debugging
echo Dumping query to $QUERYFILE
# Sed replaces the mirror's domain with the one used for the node ids in case the
# mirror was queried rather than dblp.org.
echo "${template//PLACEHOLDER/${dblp_ids[*]}}" | \
  sed "s/MIN_CITATIONS/${MIN_CITATIONS}/" | \
  sed 's/uni-trier.de/org/g' >"$QUERYFILE"
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Showing Query                                                 -'
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo Showing query:
cat $QUERYFILE

echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Showing Results                                               -'
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
#
# Issue the request
curl -X POST https://sparql.dblp.org/sparql -H "Accept: text/tab-separated-values" --data-urlencode query@"$QUERYFILE"
