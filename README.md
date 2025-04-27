# Using DBLP Sparql Engine For Great Results!

In this tutorial we show how to leverage DBLP's Sparql interface, released September 2024,
to gather a list of citations from several articles of interest and see which ones they
have in common.

These are the resources I used:

  1. DBLP's Sparql service blog post ([link](https://blog.dblp.org/2024/09/09/introducing-our-public-sparql-query-service/))
  2. DBLP Knowledge Graph tutorial ([link](https://github.com/dblp/kg/wiki/dblp-KG-Tutorial))
  3. DBLP's Sparql interface ([link](https://sparql.dblp.org/))
  4. dblp RDF schema ([link](https://dblp.org/rdf/docu/#Reference))
  5. SPARQL Wikibook ([link](https://en.wikibooks.org/wiki/SPARQL))

## Knowledge Graph Basics

A graph is a bunch of nodes and a bunch of edges connecting them.
A knowledge graph names each node and each edge.
The names of edges are known as properties or relations.

Example:

```
[ Tommy ] --- in_course ---> [ courses:id12345 ] --- course_name ---> [ Computer Science I ]
                                  |
                                  |
                             course_number
                                  |
                                  |
                                  V
                              [ CS 1337 ]
```

## Exploration

### Citations

We start by figuring out how citations to an individual article work.

For this we use the citation query example they present in their [Knowledge Graph tutorial](https://github.com/dblp/kg/wiki/dblp-KG-Tutorial).
[Query Link.](https://sparql.dblp.org/H3ks8K)

```sparql
PREFIX cito: <http://purl.org/spar/cito/>
SELECT ?citation ?citing_omid ?cited_omid ?citation_date ?citation_timespan WHERE {
  BIND(<https://w3id.org/oc/index/ci/06503267503-06703780559> as ?citation)
  ?citation cito:hasCitingEntity ?citing_omid .
  ?citation cito:hasCitedEntity ?cited_omid .
  OPTIONAL { ?citation cito:hasCitationCreationDate ?citation_date . }
  OPTIONAL { ?citation cito:hasCitationTimeSpan ?citation_timespan . } 
}
```

When we execute the query we get a single result. Many of the result values are links
we can click, like the citation: [ 06503267503-06703780559](https://w3id.org/oc/index/ci/06503267503-06703780559).

Clicking it takes us to a webpage hosted by the host of this information, which happens to be 
a different org - not DBLP!  Take a few seconds to appreciate how cool this is - we're navigating
a world wide web of open information using this query interface...

Wow!

By examining the query we can learn the structure of citations in this database.
These two lines...

```sparql
  ?citation cito:hasCitingEntity ?citing_omid .
  ?citation cito:hasCitedEntity ?cited_omid .
```

... tell us that the graph looks like this ...
```
[ Citation node ] --- hasCitingEntity ---> [ citing_node ]
    |
  hasCitedEntity
    |
    V 
[ cited_node ]
```

Rather than the simpler format one may expect:

```
[ citing_node ] --- cites ---> [ cited_node ]
```

A pedagogical aside:
This representation of citations is an example of the oft confusing but ubiquitous concept of "reification," which is the big brain synonym of "labeling."
Instead of encoding the citation relationship between the citer and the citee as an edge, 
we give the citation itself a node, thus labelling it.
This labeling of the citation itself allows us to talk about it,
discussing any number of things like when it was created and who created it,
rather than just who cited what.
We call this labeling process "reification."

### Articles

Ok, so we see how articles work - there's some node, the citer, that has the property `cito:hasCitedEntity` to another
node that represents the cited article, citee.

But, given an article like "Object Flow Integrity", how do we find out what node has the citation?

The website that hosts the citations, opencitations.net, doesn't seem to have a search interface...

We develop 2 hypotheses:

  1.  Using the DBLP website we can find how DBLP represents the article we're interested in.
  2.  There's some property that links the DBLP article node to the node that OpenCitations uses to represent it.

#### Hypothesis 1 - finding the node

1. We go to [dblp.org](https://dblp.org/) and search for our article, e.g. "Coq Hammer"

2. We find the RDF-N triples format for download

3. We open it up and ctrl-f search for the name of the article

4. We see that there's a node related to this article name

5. Looks like this node probably represents the article!

#### Hypothesis 2 - bridging the gap

Now we how to find the nodes dblp uses to represent articles, but the citation
database doesn't use these - it uses its own nodes for representing articles.
How do we bridge this gap?
What we're looking for is `some property` that relates dblp article nodes with their
corresponding cito article nodes.
```
                                    [ cito citation node ] --- hasCitedEntity ---> ...
                                          |
                                      hasCitingEntity
                                          |
                                          V
[ dblp node ] --- some property? ---> [ cito article node ]
```
                                          

We develop a query with some placeholder relation to some placeholder node
that has another place holder node pointing to it with the hasCitingEntity property.
Whew, what a mouthful.
The picture below is worth a thousand words ([Query Link](https://sparql.dblp.org/xw9mY2)).

```
[ Given Node ] ---  Property ???  --- > [ Node ???] <--- hasCitingEntity --- [ Node ??? ]
```

```sparql
PREFIX cito: <http://purl.org/spar/cito/>
SELECT ?GivenNode ?BridgeProp ?GottenNode  WHERE {
  BIND(<https://dblp.org/rec/journals/jar/CzajkaK18> as ?GivenNode)
  ?GivenNode ?BridgeProp ?GottenNode .
  ?citation cito:hasCitingEntity ?GottenNode .
}
```

Presto!
The property we're looking for, `BridgeProp` in the query, is dblp's omid property.
Now, given a dblp article we can map it to the corresponding cito article and find out
which articles it cites.
This is much easier and more reliable than pdf and html processing.

## Final


To finalize our example we hardcode some of the articles we're interested in
and add some SQL aggregations and filtering.
What we get is the query below ([Query Link](https://sparql.dblp.org/8A4MNH))

```
PREFIX cito: <http://purl.org/spar/cito/>
PREFIX dblp: <https://dblp.org/rdf/schema#>
PREFIX schema: <https://schema.org/>
SELECT ?CitedNode  ?CitedTitle ?URL
(COUNT(DISTINCT ?GivenNode) AS ?N)
(REPLACE(GROUP_CONCAT(DISTINCT ?Title ; SEPARATOR=", "), ".,", ",") AS ?Citers)
WHERE {
  Values ?GivenNode {
  # Hammer for Coq
  <https://dblp.org/rec/journals/jar/CzajkaK18>
  # Goal Translation for Hammer for Coq
  <https://dblp.org/rec/journals/corr/CzajkaK16>
  # Practical Proof Search for Coq by Type Inhabitation
  <https://dblp.org/rec/conf/cade/000120a>
  # A Shallow Embedding of Pure Type Systems into FOL
  <https://dblp.org/rec/conf/types/Czajka16>
  # Concrete Semantics with Coq and CoqHammer 2018
  <https://dblp.org/rec/conf/mkm/CzajkaEK18>
  # Concrete Semantics with Coq and CoqHammer 2016
  <https://dblp.org/rec/journals/corr/abs-1808-06413>
  }.
  ?GivenNode dblp:title ?Title.
  ?GivenNode dblp:omid ?GottenNode .
  ?citation cito:hasCitingEntity ?GottenNode .
  ?citation cito:hasCitedEntity ?CitedNode .
  ?CitedNode schema:url ?URL
  Optional {
  ?DblpCitation dblp:omid ?CitedNode .
  ?DblpCitation dblp:title ?CitedTitle. }
}
GROUP BY ?CitedNode ?CitedTitle ?URL
ORDER BY DESC(?N)
```

### But Wait, Where's the Title?

There's a missing title for some of the cited material.

Probably this Sparql endpoint doesn't host all of the information in order 
to save on resources. That means we need to FEDERATE our query, meaning we
need to shoot a part of our query off to a different endpoint that does
host the information we want.
By asking on the github forum for the dblp Knowledge Graph we find the
information we want is the dct:title hosted by purl.org ([github question](https://github.com/dblp/kg/discussions/6)).
The query below demonstrates federation and the difference in information
between two databases - not only does dct have a book that's missing from
dblp, but they disagree on the title of an article they have in common.

```

  [ citing_dblp_publ  ]  ---   dblp:omid  ---> [ citing_omid ]
          |                                           ^
      dblp:title                                      |
          |                                  cito:hasCitingEntity
          V                                           |
  [ citing_dblp_title ]                         [ citation ]
                                                      |
                                             cito:hasCitedEntity
                                                      |
                                                      V
  [ cited_dblp_publ   ]  <---  dblp:omid    --- [ cited_omid ]
          |                                           |
      dblp:title                            __________|___________
          |                    Federated   |          |           |
          V                    to: dct     |      dct:title       |
  [ cited_dblp_title  ]                    |          |           |
                                           |  [ cited_oc_title ]  |
                                           |                      |
                                           |______________________|


```
```sparql
PREFIX cito: <http://purl.org/spar/cito/>
PREFIX dblp: <https://dblp.org/rdf/schema#>
PREFIX dct: <http://purl.org/dc/terms/>
PREFIX schema: <https://schema.org/>
SELECT ?cited_omid	?cited_dblp_title	?cited_oc_title WHERE {
  VALUES ?citing_dblp_publ { <https://dblp.org/rec/conf/mkm/CzajkaEK18> } .
  ?citing_dblp_publ dblp:title ?citing_dblp_title .
  ?citing_dblp_publ dblp:omid ?citing_omid .
  ?citation cito:hasCitingEntity ?citing_omid .
  ?citation cito:hasCitedEntity ?cited_omid .
  OPTIONAL { ?cited_dblp_publ dblp:omid ?cited_omid .
    ?cited_dblp_publ dblp:title ?cited_dblp_title .
 }
# # # # # # # # # # # # # # # # # # # # #  #
#                                          #
#   This is where the federation happens!  #
#                                          #
# # # # # # # # # # # # # # # # # # # # #  #
  SERVICE <https://opencitations.net/meta/sparql> {
    OPTIONAL { ?cited_omid dct:title ?cited_oc_title . }
  }
}
```


## Where to go from here?

I hope this introduction to knowledge graphs and its demonstration was useful.
From here you can look at the included shell scripts for ideas on how to 
automate some useful queries.
You can also check out the resources below for more graphically represented 
data you can do things with.

Open Knowledge Graph resources:

  1.  [DBPedia](https://www.dbpedia.org/)
  2.  [UK Government](https://www.data.gov.uk/)
  3.  [US Government](https://data.gov/)
  4.  [BioOntology](https://www.bioontology.org/) - a database of biomed onotologies
  5.  [OpenStreetMap](https://osm2rdf.cs.uni-freiburg.de/)

Public Sparql Endpoints:

  1.  [DBpedia](https://dbpedia.org/sparql)
  2.  [DBLP](https://sparql.dblp.org/) - this is what we used in the presentation
  3.  [Open Street Maps](https://qlever.cs.uni-freiburg.de/osm-planet/q46NYb)
