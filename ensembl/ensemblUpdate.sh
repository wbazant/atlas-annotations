#!/bin/bash     

# Source script from the same (prod or test) Atlas environment as this script
scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${scriptDir}/../../bash_util/generic_routines.sh
atlasEnv=`atlas_env`

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
NEW_ENSEMBL_REL=$3
NEW_ENSEMBLGENOMES_REL=$4
#RELEASE_TYPE=$5
dbUser=$5
dbSID=$6

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

echo "Validate all Ensembl annotation sources against the release specified in them"
pushd ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl
./validateAnnSrcs.sh annsrcs
if [ $? -ne 0 ]; then
    echo "ERROR: Validation of annotation sources failed - please check notes on validation source failures on http://bar.ebi.ac.uk:8080/trac/wiki/BioentityAnnotationUpdates; fix and re-run"
    exit 1
fi
popd

pushd ${ATLAS_PROD}/bioentity_properties/ensembl

echo "Archive the previous Ensembl Data - if not done already"
if [ ! -d "$ATLAS_PROD/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}" ]; then 
    mkdir -p $ATLAS_PROD/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}
    mv * $ATLAS_PROD/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}/
else
    echo "Not archiving as this has already been done."
fi

echo "Obtain all the individual mapping files from Ensembl"
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/fetchAllEnsemblMappings.sh ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/annsrcs . > ~/tmp/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_bioentity_properties_update.log 2>&1

echo "Fetching the latest GO mappings..."
# This needs to be done because we need to replace any alternative GO ids in Ensembl mapping files with their canonical equivalents
${ATLAS_PROD}/sw/atlasinstall_prod/atlasprod/bioentity_annotations/go/fetchGoIDToTermMappings.sh ${ATLAS_PROD}/bioentity_properties/go
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get the latest GO mappings" >&2
    exit 1
fi 

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

echo "Merge all individual property files into matrices"
for species in $(ls *.tsv | awk -F"." '{print $1}' | sort | uniq); do 
   for bioentity in ensgene enstranscript ensprotein; do 
      ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/mergePropertiesIntoMatrix.pl -indir . -species $species -bioentity $bioentity -outdir . 
   done 
done 


# Compare the line counts of the new files against those in the previous
# versions downloaded.
echo "Checking all mapping files against archive ..."

# Create the path to the directory containing the mapping files we just archived above.
previousArchive=${ATLAS_PROD}/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}

# Go through the newly downloaded mapping files.
for mappingFile in $( ls *.tsv ); do

    # Count the number of lines in the new file.
    newFileNumLines=`cat $mappingFile | wc -l`

    # Cound the number of lines in the archived version of the same file.
    if [ -s ${previousArchive}/$mappingFile ]; then
        oldFileNumLines=`cat ${previousArchive}/$mappingFile | wc -l`

        # Warn to STDOUT and STDERR if the number of lines in the new file is
        # significantly lower than the number of lines in the old file.
        if [ $newFileNumLines -lt $oldFileNumLines ]; then

            # Calculate the difference between the numbers of lines.
            difference=`expr $oldFileNumLines - $newFileNumLines`

            # Only warn if the difference is greater than 2000 genes.
            # tee is used to send the message to STDOUT as well.
            if [ $difference -gt 2000 ]; then
                echo "WARNING - new version of $mappingFile has $newFileNumLines lines, old version has $oldFileNumLines lines!" | tee /dev/stderr
            fi
        fi
    fi
done

echo "Finished checking mapping files against archive."


echo "Clear previous Ensembl data from the public all subdirs of ${ATLAS_FTP}/bioentity_properties"
for dir in ensembl mirbase reactome go interpro; do
   rm -rf ${ATLAS_FTP}/bioentity_properties/${dir}/*
done

echo "Copy all array design mapping files into the public Ensembl data directory (this directory is used only for Solr index build)"
cp ${ATLAS_PROD}/bioentity_properties/ensembl/*.A-*.tsv ${ATLAS_FTP}/bioentity_properties/ensembl/

echo "Copy all matrices to the public Ensembl data directory"
for species in $(ls *.tsv | awk -F"." '{print $1}' | sort | uniq); do 
    for bioentity in ensgene enstranscript ensprotein; do
    	cp $species.$bioentity.tsv ${ATLAS_FTP}/bioentity_properties/ensembl/
    done 
done

popd


# Create files that will be loaded into the database.
echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityOrganism.dat file"

pushd ${ATLAS_PROD}/bioentity_properties
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/prepare_bioentityorganisms_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l bioentityOrganism.dat | awk '{print $1}'`
if [ "$size" -lt 200 ]; then
    echo "ERROR: Something went wrong with populating bioentityOrganism.dat file - should have more than 200 rows"
    exit 1
fi 

echo "Generate ${ATLAS_PROD}/bioentity_properties/organismEnsemblDB.dat file"
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/prepare_organismEnsemblDB_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l organismEnsemblDB.dat | awk '{print $1}'`
if [ "$size" -lt 30 ]; then
    echo "ERROR: Something went wrong with populating organismEnsemblDB.dat file - should have more than 30 rows"
    exit 1
fi 
popd

echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityName.dat file"
echo "... Generate miRBase component"
pushd ${ATLAS_PROD}/bioentity_properties/mirbase
rm -rf miRNAName.dat
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/mirbase/prepare_mirbasenames_forloading.sh
popd
echo "... Generate Ensembl component"
pushd ${ATLAS_PROD}/bioentity_properties/ensembl
rm -rf geneName.dat
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/prepare_ensemblnames_forloading.sh
popd

pushd ${ATLAS_PROD}/bioentity_properties
echo "Merge miRNAName.dat and geneName.dat into bioentityName.dat"
cp ${ATLAS_PROD}/bioentity_properties/mirbase/miRNAName.dat ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
cat ${ATLAS_PROD}/bioentity_properties/ensembl/geneName.dat >> ${ATLAS_PROD}/bioentity_properties/bioentityName.dat
# Apply sanity test
size=`wc -l bioentityName.dat | awk '{print $1}'`
if [ "$size" -lt 1000000 ]; then
    echo "ERROR: Something went wrong with populating bioentityName.dat file - should have more than 800k rows"
    exit 1
fi 

echo "Generate ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat file"
rm -rf designelementMapping.dat
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/prepare_arraydesigns_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l designelementMapping.dat | awk '{print $1}'`
if [ "$size" -lt 2000000 ]; then
    echo "ERROR: Something went wrong with populating designelementMapping.dat file - should have more than 2mln rows"
    exit 1
fi 

#################
# Copy the files to the FTP directory.
# TODO: Remove the loading part.
echo "Load bioentityOrganism.dat, organismEnsemblDB.dat, bioentityName.dat and designelementMapping.dat into staging Oracle schema"
for f in bioentityOrganism organismEnsemblDB bioentityName designelementMapping; do
    rm -rf ${f}.log; rm -rf ${f}.bad
    sqlldr $dbConnection control=${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/db/sqlldr/${f}.ctl data=${f}.dat log=${f}.log bad=${f}.bad
    if [ -s "${f}.bad" ]; then
        echo "ERROR: Failed to load ${f} into ${dbUser}@${dbSID}"
	exit 1
    fi
done

# Update the organism_kingdom table.
echo "Updating the organism_kingdom table..."
echo "delete from organism_kingdom;" | sqlplus -s $dbConnection
echo "insert into organism_kingdom (organismid, kingdom ) select organismid as organismid, case when ensembldb = 'ensembl' then 'animals' else case when ensembldb = 'metazoa' then 'animals' else ensembldb end end as kingdom from organism_ensembldb;" | sqlplus -s $dbConnection
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
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/reactome/fetchAllReactomeMappings.sh $ATLAS_PROD/bioentity_properties/reactome/
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get the latest Reactome mappings" >&2
    exit 1
fi 

echo "Copy all files to the other public data directories"
for dir in mirbase reactome go interpro; do
       cp ${dir}/*.tsv ${ATLAS_FTP}/bioentity_properties/${dir}/
done
popd


# Get mapping between Atlas experiments and Ensembl DBs that own their species
exp2ensdb=~/tmp/experiment_to_ensembldb.$$
get_experimentToEnsemblDB $dbConnection > ${exp2ensdb}.tsv

# Decorate all experiments
aux=~/tmp/decorate.$$
rm -rf $aux

for decorationType in genenames tracks R cluster gsea coexpression; do 
    echo "Decorate all experiments in ${ATLAS_PROD}/analysis with $decorationType"

    # Delete all LSF log files from previous run (if any).
    rm -rf ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.out
    rm -rf ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.err

    submitted=`${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/decorate_all_experiments.sh $decorationType ${exp2ensdb}.tsv`
    echo "monitor_decorate_lsf_submission $submitted $decorationType" >> $aux
done
for l in $(cat $aux); do
    echo "About to call: '$l'"
    decorationType=`echo $l | awk '{print $NF}'`
    failed=`eval $(echo $l)`
    if [ ! -z "$failed" ]; then
        echo "ERROR: $failed 'decorate_all_experiments.sh $decorationType' jobs failed"
        exit 1
    fi 
    echo "Copy all $decorationType decorated files to the staging area"
    ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/decorate_all_experiments.sh $decorationType ${exp2ensdb}.tsv copyonly
done
rm -rf $aux
rm -rf ${exp2ensdb}.*

# Tidy up LSF log files.
for decorationType in genenames tracks R cluster gsea coexpression; do 
    rm -rf ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.out
    rm -rf ${ATLAS_PROD}/analysis/*/*/*/*/${decorationType}*.err
done
    
