#/bin/sh

# Runs a sparql query based on the results to a dblp search.
# E.g.
#
#   $ ./common_query.sh "Hoare logic"
#   will first search dblp.org for "Hoare logic" then using up to 100
#   results will query the sparql endpoint to see what citations they
#   have in common.
#
# The second parameter specifies a popularity threshold for the results.
# E.g.
#
#   $ ./common_query.sh "Hoare logic" 5
#   will run the same query as above, but only list the works which have
#   at least 5 of the dblp-results referencing them.

# This ${PARAM:-DEFAULT} evaluates to the default if PARAM is unset or the empty string,
# otherwise it evaluates to the value of PARAM.
MIN_CITATIONS="${2:-0}"

# Use the uni-trier.de mirror when DBLP is getting DDoSed
#DBLP_SITE="https://dblp.uni-trier.de/search"
DBLP_SITE="https://dblp.org/search"

QUERY="$1"
QUERYFILE=".${QUERY// /}.sparql"
RESULTSFILE="${QUERY// /}.results"

template='''
PREFIX cito: <http://purl.org/spar/cito/>
PREFIX dblp: <https://dblp.org/rdf/schema#>
PREFIX schema: <https://schema.org/>
PREFIX dct: <http://purl.org/dc/terms/>
SELECT 
  (COUNT(DISTINCT ?GivenNode) AS ?N)
  (IF(BOUND(?CitedTitleDblp),?CitedTitleDblp,?CitedTitleCito) AS ?CitedTitle)
  ?CitedNode 
  ?URL
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
    { SELECT ?CitedNode ?CitedTitleCito
      { ?CitedNode dct:title ?CitedTitleCito_tl .
        BIND( STR(?CitedTitleCito_tl) AS ?CitedTitleCito )
      }
    }
  }
}
GROUP BY ?CitedNode ?CitedTitleDblp ?CitedTitleCito ?URL
HAVING (?N >= MIN_CITATIONS)
ORDER BY DESC(?N)
'''

declare -a dblp_ids
for id in $(curl -G --data-urlencode "q=$QUERY" "$DBLP_SITE" | ./dblp_html_to_id.sh | head -n 400); do
  dblp_ids+="<$id> "
done

# Log the query for debugging
echo Dumping query to $QUERYFILE
# Sed replaces the mirror's domain with the one used for the node ids in case the
# mirror was queried rather than dblp.org.
echo "${template//PLACEHOLDER/${dblp_ids[*]}}" |
  sed "s/MIN_CITATIONS/${MIN_CITATIONS}/" |
  sed 's/uni-trier.de/org/g' >"$QUERYFILE"
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Showing Query                                                 -'
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
cat $QUERYFILE

curl -X POST https://sparql.dblp.org/sparql -H "Accept: text/tab-separated-values" --data-urlencode query@"$QUERYFILE" >$RESULTSFILE

echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Showing Results                                               -'
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'

head $RESULTSFILE
echo ...

echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Results file:' $RESULTSFILE
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
