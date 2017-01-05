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
    xml_grep owl:Class/rdfs:label ${ontology}.owl --text_only | grep '' -n > ${ontology}.term.aux
    xml_grep owl:Class/oboInOwl:id ${ontology}.owl --text_only | grep '' -n > ${ontology}.id.aux
    perl -pi -e 's|(^\d+):|$1\t|g' ${ontology}.term.aux
    perl -pi -e 's|(^\d+):|$1\t|g' ${ontology}.id.aux
    join -t $'\t' -1 1 -2 1 ${ontology}.id.aux ${ontology}.term.aux | awk -F"\t" '{print $2"\t"$3}' > ${ontology}IDToTerm.tsv

    rm -rf ${ontology}.*.aux
    popd
}

get_ontology_alternativeID2canonicalID_mappings() {
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

    grep -P 'owl:Class|oboInOwl:id |oboInOwl:hasAlternativeId ' go.owl | perl -p -e 's|^.*oboInOwl:(.*)\s.*\>(.*)\<.*$|$1\t$2|' > ${ontology}.canonicalAlternativeID.aux
    # Example content of ${ontology}.canonicalAlternativeID.aux:
    # id\tGO:0035195
    # hasAlternativeId\tGO:0030918
    for l in $(cat ${ontology}.canonicalAlternativeID.aux); do
	echo $l | grep 'owl:Class ' > /dev/null
	if [ $? -eq 0 ]; then
	    alternativeIds=
	    id=
	fi

	echo $l | grep '^id' > /dev/null
	if [ $? -eq 0 ]; then
	    id=`echo $l | awk -F"\t" '{print $2}'`
	fi
	echo $l | grep '^hasAlternativeId' > /dev/null
	if [ $? -eq 0 ]; then
	    alternativeIds="$alternativeIds "`echo $l | awk -F"\t" '{print $2}'`
	fi
	echo $l | grep '/owl:Class' > /dev/null
	if [ $? -eq 0 ]; then
	    if [ ! -z "$id" ]; then
		for alternativeId in $(echo $alternativeIds | tr " " "\n" | sed '/^$/d'); do
		    echo -e "${alternativeId}\t${id}"
	        done
	    elif [ ! -z $alternativeIds ]; then 
		echo "ERROR: Encountered an alternative id: $alternativeId when canonical id has not been found"
		return 1
	    fi
	fi
    done > ${ontology}.alternativeID2CanonicalID.tsv
    rm -rf ${ontology}.canonicalAlternativeID.aux
    popd
}

# This is just for GO (i.e. not PO)
get_ontology_id2Depth_mappings() {
    echo "SELECT term.acc, term.term_type, min(graph_path.distance) FROM term INNER JOIN graph_path ON (term.id=graph_path.term2_id) INNER JOIN term AS ancestor ON (ancestor.id=graph_path.term1_id) AND ancestor.is_root=1 group by term.acc, term.term_type" | mysql --silent -hmysql-amigo.ebi.ac.uk -ugo_select -pamigo -P4085 go_latest | grep '^GO:'  | sort -t$'\t' -k1,1
}

get_ontology_id2term_mappings go "http://geneontology.org/ontology/go.owl" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi
get_ontology_alternativeID2canonicalID_mappings go "http://geneontology.org/ontology/go.owl" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi
get_ontology_id2term_mappings po "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/tags/live/plant_ontology.owl?view=co" $outputDir
if [ $? -ne 0 ]; then
   exit 1
fi
get_ontology_id2Depth_mappings > $outputDir/goIDToDepth.tsv
if [ $? -ne 0 ]; then
   exit 1
fi



# Append Plant Ontology terms at the end of the Gene Ontology file (Ensembl provides Plant Ontology (PO) and Gene Ontology (GO) terms - as GO terms)
cat $outputDir/poIDToTerm.tsv >> $outputDir/goIDToTerm.tsv
rm -rf $outputDir/poIDToTerm.tsv

join -t $'\t' -a 1 -1 1 -2 1 $outputDir/goIDToTerm.tsv $outputDir/goIDToDepth.tsv > $outputDir/goIDToTermDepth.tsv
rm -rf $outputDir/goIDToDepth.tsv
mv $outputDir/goIDToTermDepth.tsv $outputDir/goIDToTerm.tsv