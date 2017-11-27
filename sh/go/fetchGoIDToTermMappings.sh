#!/bin/bash
# This script retrieves the latest mapping between GO ids and terms
# Author: rpetry@ebi.ac.uk, wbazant@ebi.ac.uk
set -euo pipefail
PROJECT_ROOT=`dirname $0`/../..
export JAVA_OPTS=-Xmx3000M
IFS="
"
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir"  >&2
    exit 1
fi

echo "Fetching GO and PO owl files"
curl -s "http://geneontology.org/ontology/go.owl" > $outputDir/go.owl
curl -s "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/tags/live/plant_ontology.owl?view=co" > $outputDir/po.owl

echo "Extracting GO id -> term"
amm -s $PROJECT_ROOT/src/go/PropertiesFromOwlFile.sc terms $outputDir/go.owl \
    > $outputDir/goIDToTerm.tsv

echo "Extracting PO id -> term"
amm -s $PROJECT_ROOT/src/go/PropertiesFromOwlFile.sc terms $outputDir/po.owl \
    > $outputDir/poIDToTerm.tsv

echo "Extracting GO alternativeId -> id"
amm -s $PROJECT_ROOT/src/go/PropertiesFromOwlFile.sc alternativeIds $outputDir/go.owl \
    > $outputDir/go.alternativeID2CanonicalID.tsv


# This is just for GO (i.e. not PO)
# GO Consortium no longer publish a MySQL version of their data;
# using EBI's GOA database for GO graph distance between any two GO terms is used for mapping depth for any GO term
get_ontology_id2Depth_mappings() {
echo "select
    go_id, min(distance) min_distance
from
    (
        select
            level distance, connect_by_root child_id go_id, parent_id ancestor_id
        from
            (
                select
                    child_id, parent_id
                from
                    go.relations
                where
                    --relation_type in ('I', 'P', 'O')
                    relation_type = 'I'
            )
        connect by
            child_id = prior parent_id
    union all
        select
            0 distance, go_id, go_id ancestor_id
        from
            go.terms
        where
            is_obsolete = 'N'
    )
group by go_id, ancestor_id;" | sqlplus goselect/selectgo@goapro | grep '^GO:'  | sort -t$'\t' -rk2,2  | awk -F"\t" '{ print $1"\t"$2+1 }' | sort -buk1,1
}

get_ontology_id2Depth_mappings > $outputDir/goIDToDepth.tsv


# Append Plant Ontology terms at the end of the Gene Ontology file (Ensembl provides Plant Ontology (PO) and Gene Ontology (GO) terms - as GO terms)
cat $outputDir/poIDToTerm.tsv >> $outputDir/goIDToTerm.tsv
rm -rf $outputDir/poIDToTerm.tsv

join -t $'\t' -a 1 -1 1 -2 1 $outputDir/goIDToTerm.tsv $outputDir/goIDToDepth.tsv > $outputDir/goIDToTermDepth.tsv
rm -rf $outputDir/goIDToDepth.tsv
mv $outputDir/goIDToTermDepth.tsv $outputDir/goIDToTerm.tsv

# this 'thin' file is needed for GSEA plots as irap_GSE_piano expects two column annotations
cut -d $'\t' -f 1,2 $outputDir/goIDToTerm.tsv > $outputDir/goIDToTerm.tsv.decorate.aux
