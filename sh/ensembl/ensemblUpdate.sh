#!/bin/bash

# I used to source this script from the same (prod or test) Atlas environment as this script
# scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
pushd `dirname $0`
source ../generic_routines.sh
atlasEnv=`atlas_env`

PROJECT_ROOT=`dirname $0`/..

getPctComplete() {
    numSubmittedJobs=$1
    decorationType=$2
    successful=`grep 'Successfully completed' ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.out | wc -l`
    failed=`grep 'Exited with' ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.out | wc -l`
    if [ -z "$successful" ]; then
        successful=0
    fi
    if [ -z "$failed" ]; then
        failed=0
    fi
    done=$[$successful+$failed]
    pctComplete=`echo "scale=0; $(($done*100/$numSubmittedJobs))" | bc`
    echo $pctComplete
}

monitor_decorate_lsf_submission() {
    numSubmittedJobs=$1
    decorationType=$2
    pctComplete=`getPctComplete $numSubmittedJobs $decorationType`
    while [ "$pctComplete" -lt "100" ]; do
        sleep 60
        pctComplete=`getPctComplete $numSubmittedJobs $decorationType`
    done
    # Return number of failed jobs
    echo `grep 'Exited with' ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.out`
}


# quit if not prod user
check_prod_user
if [ $? -ne 0 ]; then
    exit 1
fi

if [ $# -lt 6 ]; then
  echo "Usage: $0 OLD_ENSEMBL_REL OLD_ENSEMBLGENOMES_REL NEW_ENSEMBL_REL NEW_ENSEMBLGENOMES_REL dbUser dbSID"
  echo "e.g. $0 75 21 75 22 ensemblgenomes atlasprd3 ATLASPRO"
  exit 1
fi

OLD_ENSEMBL_REL=$1
OLD_ENSEMBLGENOMES_REL=$2
OLD_WBPS_REL=$3
NEW_ENSEMBL_REL=$4
NEW_ENSEMBLGENOMES_REL=$5
NEW_WBPS_REL=$6
dbUser=$7
dbSID=$8

dbPass=`get_pass $dbUser`
dbConnection=${dbUser}/${dbPass}@${dbSID}

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


pushd $PROJECT_ROOT/sh

for annotationDB in ensembl wbps; do
    echo "Validate all $annotationDB annotation sources against the release specified in them"
    ./validateAnnSrcs.sh $annotationDB/annsrcs
    if [ $? -ne 0 ]; then
        echo "ERROR: Validation of $annotationDB annotation sources failed - please check notes on validation source failures on http://bar.ebi.ac.uk:8080/trac/wiki/BioentityAnnotationUpdates; fix and re-run"
        exit 1
    fi
done

popd

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

pushd ${ATLAS_PROD}/bioentity_properties/ensembl
echo "Obtain all the individual mapping files from Ensembl"
$PROJECT_ROOT/sh/ensembl/fetchAllEnsemblMappings.sh $PROJECT_ROOT/sh/ensembl/annsrcs . > ~/tmp/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_bioentity_properties_update.log 2>&1
popd

pushd ${ATLAS_PROD}/bioentity_properties/wbps
echo "Obtain all the individual mapping files from WBPS"
$PROJECT_ROOT/sh/wbps/fetchAllWbpsMappings.sh $PROJECT_ROOT/sh/wbps/annsrcs . > ~/tmp/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_wbps_${NEW_WBPS_REL}_bioentity_properties_update.log 2>&1
popd

echo "Fetching the latest GO mappings..."
# This needs to be done because we need to replace any alternative GO ids in Ensembl mapping files with their canonical equivalents
${ATLAS_PROD}/sw/atlasinstall_prod/atlasprod/bioentity_annotations/go/fetchGoIDToTermMappings.sh ${ATLAS_PROD}/bioentity_properties/go
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

#--------------------------------------------------
# # Compare the line counts of the new files against those in the previous
# # versions downloaded.
# echo "Checking all mapping files against archive ..."
#
# # Create the path to the directory containing the mapping files we just archived above.
# previousArchive=${ATLAS_PROD}/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}
#
# # Go through the newly downloaded mapping files.
# for mappingFile in $( ls *.tsv ); do
#
#     # Count the number of lines in the new file.
#     newFileNumLines=`cat $mappingFile | wc -l`
#
#     # Cound the number of lines in the archived version of the same file.
#     if [ -s ${previousArchive}/$mappingFile ]; then
#         oldFileNumLines=`cat ${previousArchive}/$mappingFile | wc -l`
#
#         # Warn to STDOUT and STDERR if the number of lines in the new file is
#         # significantly lower than the number of lines in the old file.
#         if [ $newFileNumLines -lt $oldFileNumLines ]; then
#
#             # Calculate the difference between the numbers of lines.
#             difference=`expr $oldFileNumLines - $newFileNumLines`
#
#             # Only warn if the difference is greater than 2000 genes.
#             # tee is used to send the message to STDOUT as well.
#             if [ $difference -gt 2000 ]; then
#                 echo "WARNING - new version of $mappingFile has $newFileNumLines lines, old version has $oldFileNumLines lines!" | tee /dev/stderr
#             fi
#         fi
#     fi
# done
#
# echo "Finished checking mapping files against archive."
#--------------------------------------------------


echo "Clear previous Ensembl data from the public all subdirs of ${ATLAS_FTP}/bioentity_properties"
for dir in ensembl mirbase reactome go interpro wbps; do
   rm -rf ${ATLAS_FTP}/bioentity_properties/${dir}/*
done

echo "Copy all array design mapping files into the public Ensembl data directory (this directory is used only for Solr index build)"
cp ${ATLAS_PROD}/bioentity_properties/ensembl/*.A-*.tsv ${ATLAS_FTP}/bioentity_properties/ensembl/

pushd ${ATLAS_PROD}/bioentity_properties/ensembl
echo "Copy all Ensembl matrices to the public Ensembl data directory"
for species in $(ls *.tsv | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in ensgene enstranscript ensprotein; do
    	cp $species.$bioentity.tsv ${ATLAS_FTP}/bioentity_properties/ensembl/
    done
done
popd

pushd ${ATLAS_PROD}/bioentity_properties/wbps
echo "Copy all WBPS matrices to the public WBPS data directory"
for species in $(ls *.tsv | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in wbpsgene wbpstranscript wbpsprotein; do
        cp $species.$bioentity.tsv ${ATLAS_FTP}/bioentity_properties/wbps/
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


#################
# Copy the files to the FTP directory.
echo "Load bioentityOrganism.dat, bioentityName.dat, organismKingdom.dat and designelementMapping.dat into staging Oracle schema"
for f in bioentityOrganism bioentityName organismKingdom designelementMapping; do
    rm -rf ${f}.log; rm -rf ${f}.bad
    sqlldr $dbConnection control=${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/db/sqlldr/${f}.ctl data=${f}.dat log=${f}.log bad=${f}.bad
    if [ -s "${f}.bad" ]; then
        echo "ERROR: Failed to load ${f} into ${dbUser}@${dbSID}"
        exit 1
    fi
done
#################



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

echo "Copy all files to the other public data directories"
for dir in mirbase reactome go interpro; do
       cp ${dir}/*.tsv ${ATLAS_FTP}/bioentity_properties/${dir}/
done
popd
