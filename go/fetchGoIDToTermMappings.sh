# This script retrieves the latest mapping between GO ids and terms
# Author: rpetry@ebi.ac.uk

IFS="
"
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir"  >&2
    exit 1
fi

get_ontology_id2term_mappings() {
    ontology=$1
    owlFileUrl=$2
    outputDir=$3

    pushd $outputDir
    rm -rf ${ontology}.owl*
    curl -s -o ${ontology}.owl -X GET "$owlFileUrl"
    if [ $? -ne 0 ]; then
	echo "ERROR: Failed to retrieve: ${ontology}.owl" >&2 
	return 1
    fi

    # Retrieve id's and terms separately, then (with the assumption they come back in the same order as each other)
    # join by line number; then loose the line number
    xml_grep owl:Class/rdfs:label ${ontology}.owl --text_only | grep '' -n > ${ontology}.id.aux
    xml_grep owl:Class/oboInOwl:id ${ontology}.owl --text_only | grep '' -n > ${ontology}.term.aux
    perl -pi -e 's|(^\d+):|$1\t|g' ${ontology}.id.aux
    perl -pi -e 's|(^\d+):|$1\t|g' ${ontology}.term.aux
    join -t $'\t' -1 1 -2 1 ${ontology}.term.aux ${ontology}.id.aux | awk -F"\t" '{print $2"\t"$3}' > ${ontology}IDToTerm.tsv

    rm -rf ${ontology}.*.aux
    popd
}

# This is just for GO (i.e. not PO)
get_ontology_id2Depth_mappings() {
    echo "SELECT DISTINCT term.acc, graph_path.distance FROM term INNER JOIN graph_path ON (term.id=graph_path.term2_id) INNER JOIN term AS ancestor ON (ancestor.id=graph_path.term1_id) AND ancestor.is_root=1" | mysql --silent -hmysql-amigo.ebi.ac.uk -ugo_select -pamigo -P4085 go_latest | grep '^GO:'  | sort -t$'\t' -k1,1
}

get_ontology_id2term_mappings go "http://geneontology.org/ontology/go.owl" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi
get_ontology_id2term_mappings po "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/tags/live/plant_ontology.owl?view=co" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi
get_ontology_id2Depth_mapping > $outputDir/goIDToDepth.tsv
if [ $? -ne 0 ]; then
   exit 1
fi

# Append Plant Ontology terms at the end of the Gene Ontology file (Ensembl provides Plant Ontology (PO) and Gene Ontology (GO) terms - as GO terms)
cat $outputDir/poIDToTerm.tsv >> $outputDir/goIDToTerm.tsv
rm -rf $outputDir/poIDToTerm.tsv

join -t $'\t' -a 1 -1 1 -2 1 $outputDir/goIDToTerm.tsv $outputDir/goIDToDepth.tsv > $outputDir/goIDToTermDepth.tsv
rm -rf $outputDir/goIDToDepth.tsv
rm -rf $outputDir/goIDToTerm.tsv