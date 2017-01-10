#!/bin/bash

# I used to source this script from the same (prod or test) Atlas environment as this script
# scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

PROJECT_ROOT=`dirname $0`/../..
source $PROJECT_ROOT/sh/generic_routines.sh

if [ $# -lt 6 ]; then
  echo "Usage: $0 OLD_ENSEMBL_REL OLD_ENSEMBLGENOMES_REL OLD_WBPS_REL NEW_ENSEMBL_REL NEW_ENSEMBLGENOMES_REL NEW_WBPS_REL "
  echo "e.g. $0 85 33 7 86 34 8"
  exit 1
fi

OLD_ENSEMBL_REL=$1
OLD_ENSEMBLGENOMES_REL=$2
OLD_WBPS_REL=$3
NEW_ENSEMBL_REL=$4
NEW_ENSEMBLGENOMES_REL=$5
NEW_WBPS_REL=$6

# Note that if $NEW_ENSEMBL_REL must be greater than $OLD_ENSEMBL_REL
# and $NEW_ENSEMBLGENOMES_REL must be greater than $OLD_ENSEMBLGENOMES_REL
if [ "$NEW_ENSEMBL_REL" -le "$OLD_ENSEMBL_REL" ]; then
	echo "ERROR: NEW_ENSEMBL_REL must be greater than OLD_ENSEMBL_REL"
	exit 1
fi
if [ "$NEW_ENSEMBLGENOMES_REL" -le "$OLD_ENSEMBLGENOMES_REL" ]; then
	echo "ERROR: NEW_ENSEMBLGENOMES_REL must be greater than OLD_ENSEMBLGENOMES_REL"
	exit 1
fi
if [ "$NEW_WBPS_REL" -lt "$OLD_WBPS_REL" ]; then
	echo "ERROR: NEW_WBPS_REL must not be less than OLD_WBPS_REL"
	exit 1
fi

pushd ${ATLAS_PROD}/bioentity_properties/ensembl

echo "Archive the previous Ensembl data - if not done already"
if [ ! -d "$ATLAS_PROD/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}" ]; then
    mkdir -p $ATLAS_PROD/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}
    mv * $ATLAS_PROD/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}
else
    echo "Not archiving as this has already been done."
fi
popd

pushd ${ATLAS_PROD}/bioentity_properties/wbps
echo "Archive the previous WBPS data - if not done already"
if [ ! -d "$ATLAS_PROD/bioentity_properties/archive/wbps_${OLD_WBPS_REL}" ]; then
    mkdir -p $ATLAS_PROD/bioentity_properties/archive/wbps_${OLD_WBPS_REL}
    mv * $ATLAS_PROD/bioentity_properties/archive/wbps_${OLD_WBPS_REL}
else
    echo "Not archiving as this has already been done."
fi
popd

pushd $PROJECT_ROOT
echo "Obtain the mapping files from biomarts based on annotation sources"
amm -s -c 'import $file.src.pipeline.main; main.runAll()' > ~/tmp/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_bioentity_properties_update.log 2>&1
if [ $? -ne 0 ]; then
    echo "Ammonite errored out, exiting..." >&2
    exit 1
fi
popd


echo "Fetching the latest GO mappings..."
# This needs to be done because we need to replace any alternative GO ids in Ensembl mapping files with their canonical equivalents
$PROJECT_ROOT/sh/go/fetchGoIDToTermMappings.sh ${ATLAS_PROD}/bioentity_properties/go
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get the latest GO mappings" >&2
    exit 1
fi

pushd ${ATLAS_PROD}/bioentity_properties/ensembl
echo "Replace any alternative GO ids in Ensembl mapping files with their canonical equivalents, according to ${ATLAS_PROD}/bioentity_properties/go/go.alternativeID2CanonicalID.tsv"
a2cMappingFile=${ATLAS_PROD}/bioentity_properties/go/go.alternativeID2CanonicalID.tsv
if [ ! -s $a2cMappingFile ]; then
    echo "ERROR: Missing $a2cMappingFile"
    exit 1
fi
for gof in $(ls *.go.tsv); do
    echo "${gof} ... "
    for l in $(cat $a2cMappingFile); do
	alternativeID=`echo $l | awk -F"\t" '{print $1}'`
	canonicalID=`echo $l | awk -F"\t" '{print $2}'`
	grep "${alternativeID}$" $gof > /dev/null
	if [ $? -eq 0 ]; then
	    perl -pi -e "s|${alternativeID}$|${canonicalID}|g" $gof
	    printf "$alternativeID -> $canonicalID "
	fi
    done
    echo "${gof} done "
done

echo "Merge all individual Ensembl property files into matrices"
for species in $(ls *ens*.tsv | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in ensgene enstranscript ensprotein; do
        $PROJECT_ROOT/sh/ensembl/mergePropertiesIntoMatrix.pl -indir . -species $species -bioentity $bioentity -outdir .
    done
done
popd

pushd ${ATLAS_PROD}/bioentity_properties/wbps
# Do the same for WBPS.
echo "Merge all individual WBPS property files into matrices"
for species in $(ls *wbps*.tsv | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in wbpsgene wbpsprotein wbpstranscript; do
        $PROJECT_ROOT/sh/ensembl/mergePropertiesIntoMatrix.pl -indir . -species $species -bioentity $bioentity -outdir .
    done
done
popd

# Create files that will be loaded into the database.
echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityOrganism.dat file"

pushd ${ATLAS_PROD}/bioentity_properties
$PROJECT_ROOT/sh/prepare_bioentityorganisms_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l bioentityOrganism.dat | awk '{print $1}'`
if [ "$size" -lt 200 ]; then
    echo "ERROR: Something went wrong with populating bioentityOrganism.dat file - should have more than 200 rows"
    exit 1
fi

popd

echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityName.dat file"
echo "... Generate miRBase component"
pushd ${ATLAS_PROD}/bioentity_properties/mirbase
rm -rf miRNAName.dat
$PROJECT_ROOT/sh/mirbase/prepare_mirbasenames_forloading.sh
popd
echo "... Generate Ensembl component"
pushd ${ATLAS_PROD}/bioentity_properties/ensembl
rm -rf geneName.dat
$PROJECT_ROOT/sh/ensembl/prepare_ensemblnames_forloading.sh
popd
pushd ${ATLAS_PROD}/bioentity_properties/wbps
rm -rf wbpsgeneName.dat
$PROJECT_ROOT/sh/wbps/prepare_wbpsnames_forloading.sh
popd

pushd ${ATLAS_PROD}/bioentity_properties
echo "Merge miRNAName.dat, geneName.dat and wbpsgeneName.dat into bioentityName.dat"
cp ${ATLAS_PROD}/bioentity_properties/mirbase/miRNAName.dat ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
cat ${ATLAS_PROD}/bioentity_properties/ensembl/geneName.dat >> ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
cat ${ATLAS_PROD}/bioentity_properties/wbps/wbpsgeneName.dat >> ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
# Apply sanity test
size=`wc -l bioentityName.dat | awk '{print $1}'`
if [ "$size" -lt 1000000 ]; then
    echo "ERROR: Something went wrong with populating bioentityName.dat file - should have more than 800k rows"
    exit 1
fi

echo "Generate ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat file"
rm -rf designelementMapping.dat
$PROJECT_ROOT/sh/prepare_arraydesigns_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l designelementMapping.dat | awk '{print $1}'`
if [ "$size" -lt 2000000 ]; then
    echo "ERROR: Something went wrong with populating designelementMapping.dat file - should have more than 2mln rows"
    exit 1
fi

echo "Generate ${ATLAS_PROD}/bioentity_properties/organismKingdom.dat file"
rm -rf organismKingdom.dat
$PROJECT_ROOT/sh/prepare_organismKingdom_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l organismKingdom.dat | awk '{print $1}'`
if [ "$size" -lt 50 ]; then
    echo "ERROR: Something went wrong with populating organismKingdom.dat file - should have more than 50 rows"
    exit 1
fi


# Archive the previous Reactome data. Note the files from Gramene need to be
# dealt with manually, when they send us a new one.
echo "Archive the previous Reactome Data - if not done already"
if [ ! -d "$ATLAS_PROD/bioentity_properties/archive/reactome_ens${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}" ]; then
    mkdir -p $ATLAS_PROD/bioentity_properties/archive/reactome_ens${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}
    cp $ATLAS_PROD/bioentity_properties/reactome/*.reactome.* $ATLAS_PROD/bioentity_properties/archive/reactome_ens${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}/
else
    ls $ATLAS_PROD/bioentity_properties/archive/reactome_ens${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL} | grep reactome.tsv > /dev/null
    grepCode=$?
    if [ $grepCode == 1 ]; then
        cp $ATLAS_PROD/bioentity_properties/reactome/*.reactome.* $ATLAS_PROD/bioentity_properties/archive/reactome_ens${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}/
    else
        echo "Not archiving Reactome data as this has already been done."
    fi
fi

echo "Fetching the latest Reactome mappings..."
# This needs to be done because some of Reactome's pathways are mapped to UniProt accessions only, hence so as to map them to
# gene ids - we need to use the mapping files we've just retrieved from Ensembl
$PROJECT_ROOT/sh/reactome/fetchAllReactomeMappings.sh $ATLAS_PROD/bioentity_properties/reactome/
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get the latest Reactome mappings" >&2
    exit 1
fi
