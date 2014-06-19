# This script retrieves the latest mapping between GO ids and terms
# Author: rpetry@ebi.ac.uk

IFS="
"
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir"  >&2
    exit 1
fi

f=go.owl
pushd $outputDir
rm -rf ${f}*
wget -P . -L http://geneontology.org/ontology/$f
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to retrieve: $f" >&2 
   exit 1
fi

# Retrieve id's and terms separately, then (with the assumption they come back in the same order as each other)
# join by line number; then loose the line number
xml_grep owl:Class/rdfs:label $f --text_only | grep '' -n > go.id.aux
xml_grep owl:Class/oboInOwl:id $f --text_only | grep '' -n > go.term.aux
perl -pi -e 's|(^\d+):|$1\t|g' go.id.aux
perl -pi -e 's|(^\d+):|$1\t|g' go.term.aux
join -t $'\t' -1 1 -2 1 go.term.aux go.id.aux | awk -F"\t" '{print $2"\t"$3}' > goIDToTerm.tsv

rm -rf go.*.aux
popd