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
get_ontology_id2Depth_mappings() {
    echo "SELECT term.acc, term.term_type, min(graph_path.distance) FROM term INNER JOIN graph_path ON (term.id=graph_path.term2_id) INNER JOIN term AS ancestor ON (ancestor.id=graph_path.term1_id) AND ancestor.is_root=1 group by term.acc, term.term_type" | mysql --silent -hmysql-amigo.ebi.ac.uk -ugo_select -pamigo -P4085 go_latest | grep '^GO:'  | sort -t$'\t' -k1,1
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
