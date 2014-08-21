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

get_ontology_id2term_mappings go "http://geneontology.org/ontology/go.owl" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi
get_ontology_id2term_mappings po "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/tags/live/plant_ontology.owl?view=co" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi

# Append Plant Ontology terms at the end of the Gene Ontology file (Ensembl provides Plant Ontology (PO) and Gene Ontology (GO) terms - as GO terms)
cat $outputDir/poIDToTerm.tsv >> $outputDir/goIDToTerm.tsv
rm -rf $outputDir/poIDToTerm.tsv