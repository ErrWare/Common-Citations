#!/bin/zsh

# Queries the uris of a file 1-by-1 to see which one returns typed-literal
# titles from the opencitations endpoint. This was used for debugging
# https://github.com/dblp/kg/discussions/10

BIBFILE="$1"

# Use the uni-trier.de mirror when DBLP is getting DDoSed
#DBLP_SITE="https://dblp.uni-trier.de/search"
DBLP_SITE="https://dblp.org/search"

mkdir -p debug_cache

echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
echo '-                                                                   -'
echo '-  => Building Query From Bibliography                              -'
echo '-                                                                   -'
echo '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# for title in "$(./titles_from_bib.sh "$1")"; do

# Assume we alrady have the query and the list of uris is on line 13
QUERYFILE="${BIBFILE// /}.sparql"
QUERYFILETEMP="${BIBFILE// /}.temp.sparql"

for uri in $(sed -n '13p' ${QUERYFILE}); do
  SHORTNAME="$(echo $uri | sed 's/^.*\///; s/>$//')"
  RESULTSFILE="debug_cache/${SHORTNAME}.results"
  echo $uri > $RESULTSFILE
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
      ?CitedNode dct:title ?CitedTitleCito
    }
  }
  GROUP BY ?CitedNode ?CitedTitleDblp ?CitedTitleCito ?URL
  HAVING (?N >= MIN_CITATIONS)
  ORDER BY DESC(?N)
  '''

  unused='''
    # SERVICE <https://opencitations.net/meta/sparql> {
      # SELECT ?CitedTitleCito
      # WHERE { ?CitedNode dct:title ?CitedTitleCito_tl .
      # BIND( STR(?CitedTitleCito_tl) AS ?CitedTitleCito )}
    # }
  '''

  # Log the query for debugging
  # Sed replaces the mirror's domain with the one used for the node ids in case the
  # mirror was queried rather than dblp.org.
  echo "${template//PLACEHOLDER/${uri}}" | \
    sed "s/MIN_CITATIONS/${MIN_CITATIONS}/" | \
    sed 's/uni-trier.de/org/g' >"${QUERYFILETEMP}"

  echo "Querying $uri..."
  curl -X POST https://sparql.dblp.org/sparql -H "Accept: text/tab-separated-values" --data-urlencode query@"$QUERYFILETEMP" >>$RESULTSFILE
  [ ! "$?" -eq 0 ] && echo "Error for $uri"
  echo '---------------'
done
