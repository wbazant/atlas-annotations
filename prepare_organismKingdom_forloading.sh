# This script retrieves mapping between organism and a part of Ensembl, e.g. ensembl, plants, fungi and metazoa
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
fi

# I used to source this script from the same (prod or test) Atlas environment as this script
# scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ./generic_routines.sh
atlasEnv=`atlas_env`

today="`eval date +%Y-%m-%d`"
aux="/tmp/prepare_organismKingdom_forloading.${today}.$$.aux"
rm -rf $aux
rm -rf $outputDir/organismEnsemblDB.dat

grep 'databaseName=' $ATLAS_PROD/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/annsrcs/*  | awk -F"/" '{print $NF}' | sed 's|:databaseName=| |' | sort | uniq > $aux

# Add any missing WBPS species. Note C. elegans is already in the list we
# collected from the Ensembl files in the line above because we are collecting
# array design mappings from there, so we don't need to add it again.
wbpsSpecies=`ls $ATLAS_PROD/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/wbps/annsrcs`
for species in $wbpsSpecies; do
    annsrcFile=$ATLAS_PROD/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/wbps/annsrcs/$species
    # Just make sure this is a real annotation source and not something else.
    grep 'datasetName=' $annsrcFile > /dev/null
    if [ $? -eq 0 ]; then
        grep $species $aux > /dev/null
        if [ $? -ne 0 ]; then
            # Only add this species if it wasn't found in Ensembl annotation sources.
            echo "$species wbps" >> $aux
        else
            echo "$species already found in Ensembl species."
        fi
    fi
done

if [ ! -s "$outputDir/bioentityOrganism.dat" ]; then 
    echo "ERROR: $outputDir/bioentityOrganism.dat does not exist or is empty - cannot map EnsemblDBs in $aux to organism ids"
    exit 1
fi

for l in $(cat $aux); do
    organism=`echo $l | awk '{print $1}'`
    bioentityOrganism=`capitalize_first_letter $organism | tr "_" " "`
    database=`echo $l | awk '{print $2}'`
    organismId=`grep -P "\t${bioentityOrganism}" $outputDir/bioentityOrganism.dat | awk -F"\t" '{print $1}'`
    if [ ! -z "$organismId" ]; then
        
        if [ $database == "ensembl" ]; then
            kingdom=animals
        elif [ $database == "metazoa" ]; then
            kingdom=animals
        elif [ $database == "wbps" ]; then
            kingdom=animals
        elif [ $database == "plants" ]; then
            kingdom=plants
        elif [ $database == "fungi" ]; then
            kingdom=fungi
        else
            echo "ERROR: unrecognised database: $database"
            exit 1
        fi

        echo -e "${organismId}\t${kingdom}" >> $outputDir/organismKingdom.dat
    else
        echo "ERROR: Failed to retrieve organismId: $organismId for $bioentityOrganism from $outputDir/bioentityOrganism.dat"
        exit 1
    fi
done

# Remove auxiliary file(s)
rm -rf $aux
exit 0
