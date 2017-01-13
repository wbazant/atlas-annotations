#!/bin/bash

# I used to source this script from the same (prod or test) Atlas environment as this script
# scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

PROJECT_ROOT=`dirname $0`/../..
source $PROJECT_ROOT/sh/generic_routines.sh

if [ $# -lt 3 ]; then
  echo "Usage: $0 NEW_ENSEMBL_REL NEW_ENSEMBLGENOMES_REL NEW_WBPS_REL "
  echo "e.g. $0 86 34 8"
  exit 1
fi

NEW_ENSEMBL_REL=$1
NEW_ENSEMBLGENOMES_REL=$2
NEW_WBPS_REL=$3

function symlinkAndArchive() {
  mkdir -p $2
  rm $1 2>/dev/null
  ln -s $2 $1
}
echo "Shifting the symlinks to new versions of Ensembl, Ensembl Genomes and WBPS"
symlinkAndArchive $ATLAS_PROD/bioentity_properties/ensembl $ATLAS_PROD/bioentity_properties/archive/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}
symlinkAndArchive $ATLAS_PROD/bioentity_properties/reactome $ATLAS_PROD/bioentity_properties/archive/reactome_ens${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}
symlinkAndArchive $ATLAS_PROD/bioentity_properties/wbps $ATLAS_PROD/bioentity_properties/archive/wbps_${NEW_WBPS_REL}

echo "Fetching the latest GO mappings..."
# This needs to be done because we need to replace any alternative GO ids in Ensembl mapping files with their canonical equivalents
$PROJECT_ROOT/sh/go/fetchGoIDToTermMappings.sh ${ATLAS_PROD}/bioentity_properties/go
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get the latest GO mappings" >&2
    exit 1
fi

pushd $PROJECT_ROOT
echo "Obtain the mapping files from biomarts based on annotation sources"
export JAVA_OPTS=-Xmx3000M
amm -s -c 'import $file.src.pipeline.main; main.runAll()'
if [ $? -ne 0 ]; then
    echo "Ammonite errored out, exiting..." >&2
    exit 1
fi
popd

echo "Merge all individual Ensembl property files into matrices"
for species in $(ls $PROJECT_ROOT/annsrcs/ensembl | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in ensgene enstranscript ensprotein; do
        $PROJECT_ROOT/sh/ensembl/mergePropertiesIntoMatrix.pl -indir ${ATLAS_PROD}/bioentity_properties/ensembl -species $species -bioentity $bioentity -outdir ${ATLAS_PROD}/bioentity_properties/ensembl
    done
done

# Do the same for WBPS.
echo "Merge all individual WBPS property files into matrices"
for species in $(ls $PROJECT_ROOT/annsrcs/wbps  | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in wbpsgene wbpsprotein wbpstranscript; do
        $PROJECT_ROOT/sh/ensembl/mergePropertiesIntoMatrix.pl -indir ${ATLAS_PROD}/bioentity_properties/wbps -species $species -bioentity $bioentity -outdir ${ATLAS_PROD}/bioentity_properties/wbps
    done
done

# Create files that will be loaded into the database.
echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityOrganism.dat file"
$PROJECT_ROOT/sh/prepare_bioentityorganisms_forloading.sh ${ATLAS_PROD}/bioentity_properties

# Apply sanity test
size=`wc -l ${ATLAS_PROD}/bioentity_properties/bioentityOrganism.dat | awk '{print $1}'`
if [ "$size" -lt 200 ]; then
    echo "ERROR: Something went wrong with populating bioentityOrganism.dat file - should have more than 200 rows"
    exit 1
fi


echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityName.dat file"
echo "... Generate miRBase component"
rm -rf ${ATLAS_PROD}/bioentity_properties/mirbase/miRNAName.dat
$PROJECT_ROOT/sh/mirbase/prepare_mirbasenames_forloading.sh

echo "... Generate Ensembl component"
find -L $ATLAS_PROD/bioentity_properties/ensembl -name '*ensgene.symbol.tsv' \
| xargs $PROJECT_ROOT/sh/ensembl/prepare_names_for_loading.sh $ATLAS_PROD/bioentity_properties/bioentityOrganism.dat \
> ${ATLAS_PROD}/bioentity_properties/ensembl/geneName.dat

echo "... Generate WBPS component"
find -L $ATLAS_PROD/bioentity_properties/wbps -name '*wbpsgene.symbol.tsv' \
| xargs $PROJECT_ROOT/sh/ensembl/prepare_names_for_loading.sh $ATLAS_PROD/bioentity_properties/bioentityOrganism.dat \
> ${ATLAS_PROD}/bioentity_properties/wbps/wbpsgeneName.dat

echo "Merge miRNAName.dat, geneName.dat and wbpsgeneName.dat into bioentityName.dat"
cp ${ATLAS_PROD}/bioentity_properties/mirbase/miRNAName.dat ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
cat ${ATLAS_PROD}/bioentity_properties/ensembl/geneName.dat >> ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
cat ${ATLAS_PROD}/bioentity_properties/wbps/wbpsgeneName.dat >> ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
# Apply sanity test
size=`wc -l ${ATLAS_PROD}/bioentity_properties/bioentityName.dat | awk '{print $1}'`
if [ "$size" -lt 1000000 ]; then
    echo "ERROR: Something went wrong with populating bioentityName.dat file - should have more than 1mln rows, only had $size"
    exit 1
fi

echo "Generate ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat file"
rm -rf ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat

find -L $ATLAS_PROD/bioentity_properties/ensembl -name '*A-*.tsv' \
| xargs $PROJECT_ROOT/sh/prepare_array_designs_for_loading.sh "gene" \
>> ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat

find -L $ATLAS_PROD/bioentity_properties/mirbase -name '*A-*.tsv' \
| xargs $PROJECT_ROOT/sh/prepare_array_designs_for_loading.sh "mature_miRNA" \
>> ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat

# Apply sanity test
size=`wc -l ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat | awk '{print $1}'`
if [ "$size" -lt 2000000 ]; then
    echo "ERROR: Something went wrong with populating designelementMapping.dat file - should have more than 2mln rows"
    exit 1
fi

echo "Generate ${ATLAS_PROD}/bioentity_properties/organismKingdom.dat file"
rm -rf ${ATLAS_PROD}/bioentity_properties/organismKingdom.dat
$PROJECT_ROOT/sh/prepare_organismKingdom_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l ${ATLAS_PROD}/bioentity_properties/organismKingdom.dat | awk '{print $1}'`
if [ "$size" -lt 50 ]; then
    echo "ERROR: Something went wrong with populating organismKingdom.dat file - should have more than 50 rows"
    exit 1
fi

echo "Fetching the latest Reactome mappings..."
# This needs to be done because some of Reactome's pathways are mapped to UniProt accessions only, hence so as to map them to
# gene ids - we need to use the mapping files we've just retrieved from Ensembl
$PROJECT_ROOT/sh/reactome/fetchAllReactomeMappings.sh $ATLAS_PROD/bioentity_properties/reactome/
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get the latest Reactome mappings" >&2
    exit 1
fi
