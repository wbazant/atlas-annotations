#!/bin/bash
# This script retrieves Ensembl gene identifier - Reactome pathway identifier - Reactome pathway name triples and puts them in ${organism}.reactome.tsv files, depending on the organism of the Ensembl gene identifier
# Author: rpetry@ebi.ac.uk

# Change reactomedev.oicr.on.ca to reactomerelease.oicr.on.ca when the latter one is up again
url="http://reactomedev.oicr.on.ca:5555/biomart/martservice"
query="query=<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE Query><Query virtualSchemaName = \"default\" formatter = \"TSV\" header = \"1\" uniqueRows = \"1\" count = \"\" datasetConfigVersion = \"0.6\"><Dataset name = \"pathway\" interface = \"default\" ><Attribute name = \"referencedatabase_ensembl\"/><Attribute name = \"referencednasequence__dm_species__displayname\"/><Attribute name = \"stableidentifier_identifier\"/><Attribute name = \"_displayname\"/></Dataset></Query>"

outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
    exit 1
fi

pushd $outputDir
IFS="
"

start=`date +%s`
curl -s -G -X GET --data-urlencode "$query" "$url" | tail -n +2 | sort -k 1,1 | grep -vP '^\t' > aux

# Lower-case and replace space with underscore in all organism names; create files with headers for each organism
cat aux | awk -F"\t" '{print $2}' | sort | uniq > aux.organisms
for organism in $(cat aux.organisms); do
    newOrganism=`echo $organism | tr '[A-Z]' '[a-z]' | tr ' ' '_'`
    perl -pi -e "s|$organism|$newOrganism|g" aux
    echo -e "ensgene\tpathwayid\tpathwayname" > ${newOrganism}.reactome.tsv
 done

# Append data retrieved from REACTOME into each of the species-specific files 
# (each file contains the portion of the original data for the species in that file's name)
awk -F"\t" '{print $1"\t"$3"\t"$4>>$2".reactome.tsv"}' aux

rm -rf aux*
end=`date +%s`
echo "Operation took: "`expr $end - $start`" s"

popd




