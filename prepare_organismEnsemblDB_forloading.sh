# This script retrives mapping between organism and a part of Ensembl, e.g. ensembl, plants, fungi and metazoa
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
fi

source ${ATLAS_PROD}/sw/atlasprod/bash_util/generic_routines.sh

today="`eval date +%Y-%m-%d`"
aux="/tmp/prepare_organismEnsemblDB_forloading.${today}.$$.aux"
rm -rf $aux
rm -rf $outputDir/organismEnsemblDB.dat

grep 'databaseName=' $ATLAS_PROD/sw/atlasprod/bioentity_annotations/ensembl/annsrcs/*  | awk -F"/" '{print $NF}' | sed 's|:databaseName=| |' | sort | uniq > $aux

if [ ! -s "$outputDir/bioentityOrganism.dat" ]; then 
    echo "ERROR: $outputDir/bioentityOrganism.dat does not exist ir is empty - cannot map EnsemblDBs in $aux to organism ids"
    exit 1
fi

for l in $(cat $aux); do
    organism=`echo $l | awk '{print $1}'`
    bioentityOrganism=`capitalize_first_letter $organism | tr "_" " "`
    ensemblDB=`echo $l | awk '{print $2}'`
    organismId=`grep -P "\t${bioentityOrganism}" $outputDir/bioentityOrganism.dat | awk -F"\t" '{print $1}'`
    if [ ! -z "$organismId" ]; then
	echo -e "${organismId}\t${ensemblDB}" >> $outputDir/organismEnsemblDB.dat
    else
	echo "ERROR: Failed to retrieve organismId: $organismId for $bioentityOrganism from $outputDir/bioentityOrganism.dat"
	exit 1
    fi
done

# Remove auxiliary file(s)
rm -rf $aux
exit 0
