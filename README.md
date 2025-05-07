# Using DBLP Sparql Engine For Great Results!

You're a research student given a list of papers to read.
But what background knowledge do you need to put them all into context?

In this tutorial we show how to find the citations common to a given list of papers by querying DBLP's knowledge graph through their public SPARQL ([wikipedia](https://en.wikipedia.org/wiki/SPARQL)) endpoint.
For those not in the know, [DBLP](https://dblp.org/) is the premier go-to premium platinum-standard database for computer science articles.

These are the resources I used to develop this tutorial:

  1. DBLP's Sparql service blog post ([link](https://blog.dblp.org/2024/09/09/introducing-our-public-sparql-query-service/))
  2. DBLP Knowledge Graph tutorial ([link](https://github.com/dblp/kg/wiki/dblp-KG-Tutorial))
  3. DBLP's Sparql interface ([link](https://sparql.dblp.org/))
  4. dblp RDF schema ([link](https://dblp.org/rdf/docu/#Reference))
  5. SPARQL Wikibook ([link](https://en.wikibooks.org/wiki/SPARQL))
  6. W3C Sparql Language Reference ([link](https://w3c.github.io/sparql-query/spec/))

## Knowledge Graph Basics

A graph is a bunch of nodes and a bunch of edges connecting them.
In a Knowledge Graph ([wikipedia](https://en.wikipedia.org/wiki/Knowledge_graph)),
each node and each edge has a label.
The labels of edges are known as properties or relations.
The nodes represent entities, and the edges represent their properties or relationships to other entities.

Example:

```
[ Tommy ] --- in_course ---> [ courses:id12345 ] --- course_name ---> "Computer Science I"
                                  |
                                  |
                             course_number
                                  |
                                  |
                                  V
                              [ CS 1337 ]
```

Typically these graphs are stored in [RDF](https://en.wikipedia.org/wiki/Resource_Description_Framework) format, which can be represented in many ways.
The most simple is [N-Triples](https://en.wikipedia.org/wiki/N-Triples), which stores them as plain text triples in the format "<entity1> <property name> (<entity2> | value) ."
Where `entity1`` is always a node, `property name` is the name of the edge (e.g. "course_number", or "in_course")"), and the third place is either another node, `entity2`, or a value (e.g. a string or number).

Our example graph above would thus be represented as the RDF N-Triples file:

```ntriples
<Tommy> <in_course> <courses:id12345> .
<courses:id12345> <course_name> "Computer Science I" .
<courses:id12345> <course_number> <CS 1337> .
```

Here's a more realistic example pulled from a later step in the tutorial:

```ntriples
<https://dblp.org/rec/journals/jar/CzajkaK18> <http://www.w3.org/2002/07/owl#sameAs> <http://www.wikidata.org/entity/Q90699792> .
<https://dblp.org/rec/journals/jar/CzajkaK18> <http://www.w3.org/2000/01/rdf-schema#label> "Lukasz Czajka and Cezary Kaliszyk: Hammer for Coq: Automation for Dependent Type Theory. (2018)" .
<https://dblp.org/rec/journals/jar/CzajkaK18> <https://dblp.org/rdf/schema#publishedInStream> <https://dblp.org/streams/journals/jar> .
<https://dblp.org/rec/journals/jar/CzajkaK18> <https://dblp.org/rdf/schema#pagination> "423-453" .
```

**Note** - we use entity, node, and id interchangeably to refer to the ... entity, node, or id...

## Exploration

### Citations

<FLAG></FLAG>
We start our exploration of DBLP's public knowledge graph by figuring out how citations to an individual article are stored.

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

Ok, so we've seen how citations work - there's a citation node and a node each for the citer and citee.
The citation node has the property `cite:hasCitingEntity` to the citing article and `cito:hasCitedEntity` to the cited article.

But, given an article like "Object Flow Integrity", how do we find out which node is the "CitingEntity" we're looking for?
In other words, which node corresponds to our article, "Object Flow Integrity".

The website that hosts the citations, [opencitations.net](https://opencitations.net/), doesn't seem to have a search interface that indexes by article name...
This creates a problem - we want to turn an article, starting with its name, into a list of its citations.
We can't search OpenCitations for citations by giving it an article name.
And we can't search DBLP for citations...
We have to find a way to start with an article name, translate it through DBLP to query OpenCitations for the article's citations.

```
                     .========.                         .=================.
                     |        |                         |                 |
    article name --- |  DBLP  | --> cito:article_id --- |  OpenCitations  | --> citations
                     |        |                         |                 |
                     |________|                         |_________________|
```
We develop 2 hypotheses:

  1.  Using the DBLP website we can find how DBLP represents the article we're interested in.
  2.  There's some property that links the DBLP article node to the node that OpenCitations uses to represent it.

#### Hypothesis 1 - finding the node

1. We go to [dblp.org](https://dblp.org/) and search for our article, e.g. "Coq Hammer"

2. Under the download button next to the search result we find and download the "RDF-N Triples" representation of the result.

3. We open it up and ctrl-f search for the name of the article, e.g. "Hammer for Coq"

4. We see that there's a node related to this article name - specifically the `<https://dblp.org/rec/journals/jar/CzajkaK18>` entry of the triple:

    ```ntriples
    <https://dblp.org/rec/journals/jar/CzajkaK18>
      <https://dblp.org/rdf/schema#title>
      "Hammer for Coq: Automation for Dependent Type Theory." .
    ```

5. Looks like this node probably represents the article! But we don't have the cito:article_id just yet... this is only the id DBLP uses.

#### Hypothesis 2 - bridging the gap

Now we know how to find the nodes DBLP uses to represent articles, but the citation
database (opencitations.net) doesn't use these - it uses its own nodes for representing articles.
How do we bridge this gap?
How do we get OpenCitation's id for our article?
What we're looking for is `some property` that relates DBLP article nodes with their
corresponding OpenCitations (cito) article nodes.
```
  + DBLP - - - - - - - -  + - - - OpenCitations - - - -
  :                       :
  : [ dblp node ]         :    [ cito citation node ] --- hasCitedEntity ---> ...
  :    |                  :        |
  :    |                  :      hasCitingEntity
  :    |                  :        |
  :    |                  :        V
  :    + some property? -----> [ cito article node ]
  :                       :
  : _ _ _ _ _ _ _ _ _ _ _ : _ _ _ _ _ _ _ _ _ _ _ _ _ _
```


To find the `some property` we're looking for let's develop a query with some placeholder relation to some placeholder node
that has another placeholder node pointing to it with the hasCitingEntity property.
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

```
Query Results:
GivenNode	                                  BridgeProp                      	GottenNode
https://dblp.org/rec/journals/jar/CzajkaK18	https://dblp.org/rdf/schema#omid	https://w3id.org/oc/meta/br/061302860330
...                                         ...                               ...

```

Presto!
The property we're looking for, `BridgeProp` in the query, is DBLP's `<dblp:omid>` property.
(What does omid stand for? I don't know. I do know that the `dblp:` prefix before the property name is a shorthand for the namespace, you can see it in use in the queries :)
Now, given a DBLP article we can map it to the corresponding OpenCitations article and find out
which articles it cites.
This is much easier and more reliable than trying to process pdfs of articles and normalizing their citation formats.

## Final


To finalize our example we hardcode some of the articles we're interested in
and add some standard SQL aggregations and filtering.
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

The title is missing for one of the cited articles!

Probably this SPARQL endpoint doesn't host all of the information in order
to save on resources. That means we need to FEDERATE our query, meaning we
need to shoot off a part of our query to a different endpoint that does
host the information we want.
By asking on the DBLP's Knowledge Graph github forum we find the
information we want is the dct:title hosted by purl.org ([github question](https://github.com/dblp/kg/discussions/6)).
The query below demonstrates federation and the difference in information
between two databases - not only does dct have an article that's missing from
DBLP, but they disagree on the title of an article they have in common.
[Query Link](https://sparql.dblp.org/nuVANR).

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
# # # # # # # # # # # # # # # # # # # # # # #
#                                           #
#   This is where the federation happens!*  #
#                                           #
# # # # # # # # # # # # # # # # # # # # # # #
  SERVICE <https://opencitations.net/meta/sparql> {
    {
      SELECT ?cited_omid ?cited_oc_title
      WHERE { ?cited_omid dct:title ?cited_oc_title_tl .
      BIND ( STR(?cited_oc_title_tl) AS ?cited_oc_title )}
    }
  }
# * The remote database stores some titles as typed_literal's which
#   our host database doesn't understand, so we have to convert them
#   to strings there before sending them back to the host.
}
```

## Polishing the Query

We can simplify our query by using [property paths](https://en.wikibooks.org/wiki/SPARQL/Printable_version#Property_paths).
Property paths allow us to "skip over" nodes when defining a relationship
between two nodes that relies on intermediate nodes that we don't care about
otherwise.
For instance, in our citer-citee relationship, we don't really care about the citation
node that sits in the middle. Remember: we have 3 nodes and 2 properties like this:

```
  [ citing_omid ]
         ^
         |
cito:hasCitingEntity
         |
   [ citation ]
         |
cito:hasCitedEntity
         |
         V
   [ cited_omid ]
```

And in the query it looks like this:

```sparql
  ?citation cito:hasCitingEntity ?citing_omid .
  ?citation cito:hasCitedEntity ?cited_omid .
```

Simplified, it becomes:

```
  ?citing_omid ^cito:hasCitingEntity/cito:hasCitedEntity ?cited_omid .
```

Arcane? A little. Perplexing? Maybe. Confounding? Read on.

We'll use only 2 new bits of syntax for our property paths - the forward slash `/` and the carrot `^`.
The forward slash means "and the next property is..."
It tells us to keep going without giving the node we just pointed to a name.
The carrot is called the "inverse link" and means "the property pointing to this node."
Simply, instead of `A prop B.` the carrot allows us to write `B ^prop A.`
The carrot was necessary to omit the citation node because it sits in between the two nodes we care about--
starting from one of the nodes, we'd have to traverse some edge backwards.

Let's zoom in on this example, reading the SPARQL syntax from left to right and developing a mental model of what's going on.

  * Starting at the left, `?citing_omid` tells us we're starting with a node:

    ```sparql
       _____________
      |             |
      | citing_omid |
      |_____________|
    ```

  * Then the carrot `^` tells us the next property actually points to the current node, `citing_omid`:

    ```sparql
       _____________
      |             |
      | citing_omid |<==
      |_____________|
    ```

  * `cito:hasCitingEntity` tells us the name of the property.

    ```sparql
       _____________
      |             |
      | citing_omid |<== cito:hasCitingEntity
      |_____________|
    ```

  * The slash `/` says "and the next property is..." so we won't give this node a name...

    ```sparql
       _____________
      |             |                             __
      | citing_omid |<== cito:hasCitingEntity == |__|
      |_____________|
    ```

  * `cite:hasCitedEntity` tells us the name of the next property.

    ```sparql
       _____________
      |             |                             __
      | citing_omid |<== cito:hasCitingEntity == |__| == cito:hasCitedEntity ==>
      |_____________|
    ```

  * Finally, `?cited_omid` names the present node.

    ```sparql
       _____________                                                             ____________
      |             |                             __                            |            |
      | citing_omid |<== cito:hasCitingEntity == |__| == cito:hasCitedEntity ==>| cited_omid |
      |_____________|                                                           |____________|
    ```

Now we don't have to name the nodes we don't care about in our picture above.
We'll replace their names with `?` in the diagram. ([Query Link](https://sparql.dblp.org/9k6dPO)).


```
  [ citing_dblp_publ  ]  ---   dblp:omid  ---> [      ?      ]
          |                                           ^
      dblp:title                                      |
          |                                  cito:hasCitingEntity
          V                                           |
  [ citing_dblp_title ]                             [ ? ]
                                                      |
                                             cito:hasCitedEntity
                                                      |
                                                      V
  [       ?           ]  <---  dblp:omid    --- [ cited_omid ]
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
  ?citing_dblp_publ dblp:omid/^cito:hasCitingEntity/cito:hasCitedEntity ?cited_omid.
  OPTIONAL {
    ?cited_omid ^dblp:omid/dblp:title ?cited_dblp_title.
  }
# # # # # # # # # # # # # # # # # # # # # # #
#                                           #
#   This is where the federation happens!   #
#                                           #
# # # # # # # # # # # # # # # # # # # # # # #
  SERVICE <https://opencitations.net/meta/sparql> {
    {
      SELECT ?cited_omid ?cited_oc_title
      WHERE { ?cited_omid dct:title ?cited_oc_title_tl .
      BIND ( STR(?cited_oc_title_tl) AS ?cited_oc_title )}
    }
  }
}
```

Beautiful, we've managed to eliminate 3 nodes ~~at the cost of using~~ and learn more advanced SPARQL features.

## Where to go from here?

I hope this introduction to knowledge graphs and its demonstration was useful.
From here you can look at the included shell scripts for ideas on how to
automate some useful queries.
You can also check out the resources below for more knowledge graphs you can explore.

Open Knowledge Graph databases:

  1.  [DBPedia](https://www.dbpedia.org/)
  2.  [UK Government](https://www.data.gov.uk/)
  3.  [US Government](https://data.gov/)
  4.  [BioOntology](https://www.bioontology.org/) - a database of biomed onotologies
  5.  [OpenStreetMap](https://osm2rdf.cs.uni-freiburg.de/)

Public Sparql Endpoints:

  1.  [DBpedia](https://dbpedia.org/sparql)
  2.  [DBLP](https://sparql.dblp.org/) - this is what we used in the presentation
  3.  [Open Street Maps](https://qlever.cs.uni-freiburg.de/osm-planet/q46NYb)

## Acknowledgements

Sincere gratitude to Hannah Bast and Marcel Ackermann for helping me through my questions
on the dblp/kg discussions linked below.

1. https://github.com/dblp/kg/discussions/6
2. https://github.com/dblp/kg/discussions/7
3. https://github.com/dblp/kg/discussions/9
4. https://github.com/dblp/kg/discussions/10
