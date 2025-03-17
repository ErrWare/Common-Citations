#/bin/sh

# Runs a sparql query based on the results to a dblp search.
# E.g.
#
#   $ ./common_query.sh "Hoare logic"
#   will first search dblp.org for "Hoare logic" then using up to 100
#   results will query the sparql endpoint to see what citations they
#   have in common.

QUERY="$1"
QUERYFILE="${1// /}.sparql"
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
ORDER BY DESC(?N)
'''

declare -a dblp_ids
for id in $(curl -G --data-urlencode "q=$QUERY" https://dblp.org/search | ./dblp_html_to_id.sh | head -n 100); do
  dblp_ids+="<$id> "
done

echo Dumping query to $QUERYFILE
echo "${template//PLACEHOLDER/${dblp_ids[*]}}" >"$QUERYFILE"

curl -X POST https://sparql.dblp.org/sparql -H "Accept: text/tab-separated-values" --data-urlencode query@"$QUERYFILE"
