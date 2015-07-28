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

if [ $# -lt 8 ]; then
  echo "Usage: $0 OLD_ENSEMBL_REL OLD_ENSEMBLGENOMES_REL NEW_ENSEMBL_REL NEW_ENSEMBLGENOMES_REL RELEASE_TYPE dbUser dbSID stagingTomcatAdmin"
  echo "e.g. $0 75 21 75 22 ensemblgenomes atlasprd3 ATLASREL"
  exit 1
fi 

OLD_ENSEMBL_REL=$1
OLD_ENSEMBLGENOMES_REL=$2
NEW_ENSEMBL_REL=$3
NEW_ENSEMBLGENOMES_REL=$4
RELEASE_TYPE=$5
dbUser=$6
dbSID=$7
stagingTomcatAdmin=$8


tmp="/nfs/public/rw/homes/fg_atlas/tmp"
dbPass=`get_pass $dbUser`
dbPass=`get_pass $dbUser`
stagingTomcatAdminPass=`get_pass $stagingTomcatAdmin`
stagingServer=ves-hx-76

# Annotation release will always be either for just Ensembl or just for Ensembl Genomes, but never for both - as the latter always releases some time after the former
# Note that if RELEASE_TYPE=ensembl, then $NEW_ENSEMBL_REL must be greater than $OLD_ENSEMBL_REL
# and if RELEASE_TYPE=ensemblgenomes, then $NEW_ENSEMBLGENOMES_REL must be greater than $OLD_ENSEMBLGENOMES_REL
echo $RELEASE_TYPE | grep -P 'ensembl|ensemblgenomes' > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Unrecognised RELEASE_TYPE: $RELEASE_TYPE - should be either ensembl or ensemblgenomes"
    exit 1
elif [ "$RELEASE_TYPE" == "ensembl" ]; then
    if [ "$NEW_ENSEMBL_REL" -le "$OLD_ENSEMBL_REL" ]; then
	echo "ERROR: For RELEASE_TYPE: $RELEASE_TYPE, NEW_ENSEMBL_REL must be greater than OLD_ENSEMBL_REL"
	exit 1
    fi
elif [ "$RELEASE_TYPE" == "ensemblgenomes" ]; then 
    if [ "$NEW_ENSEMBLGENOMES_REL" -le "$OLD_ENSEMBLGENOMES_REL" ]; then
	echo "ERROR: For RELEASE_TYPE: $RELEASE_TYPE, NEW_ENSEMBLGENOMES_REL must be greater than OLD_ENSEMBLGENOMES_REL"
	exit 1
    fi
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
fi

echo "Obtain all the individual mapping files from Ensembl"
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/fetchAllEnsemblMappings.sh ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/annsrcs . > ${tmp}/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_bioentity_properties_update.log 2>&1

echo "Merge all individual property files into matrices"
for species in $(ls *.tsv | awk -F"." '{print $1}' | sort | uniq); do 
   for bioentity in ensgene enstranscript ensprotein; do 
      ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/mergePropertiesIntoMatrix.pl -indir . -species $species -bioentity $bioentity -outdir . 
   done 
done 

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

echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityOrganism.dat sqlloader file for loading into the staging DB instance"

pushd ${ATLAS_PROD}/bioentity_properties
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/prepare_bioentityorganisms_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l bioentityOrganism.dat | awk '{print $1}'`
if [ "$size" -lt 200 ]; then
    echo "ERROR: Something went wrong with populating bioentityOrganism.dat file - should have more than 200 rows"
    exit 1
fi 

echo "Generate ${ATLAS_PROD}/bioentity_properties/organismEnsemblDB.dat sqlloader file for loading into the staging DB instance"
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/prepare_organismEnsemblDB_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l organismEnsemblDB.dat | awk '{print $1}'`
if [ "$size" -lt 30 ]; then
    echo "ERROR: Something went wrong with populating organismEnsemblDB.dat file - should have more than 30 rows"
    exit 1
fi 
popd

echo "Generate ${ATLAS_PROD}/bioentity_properties/bioentityName.dat sqlloader file for loading into the staging DB instance"
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

echo "Generate ${ATLAS_PROD}/bioentity_properties/designelementMapping.dat sqlloader file for loading into the staging DB instance"
rm -rf designelementMapping.dat
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/prepare_arraydesigns_forloading.sh ${ATLAS_PROD}/bioentity_properties
# Apply sanity test
size=`wc -l designelementMapping.dat | awk '{print $1}'`
if [ "$size" -lt 2000000 ]; then
    echo "ERROR: Something went wrong with populating designelementMapping.dat file - should have more than 2mln rows"
    exit 1
fi 

echo "Load bioentityOrganism.dat, organismEnsemblDB.dat, bioentityName.dat and designelementMapping.dat into staging Oracle schema"
for f in bioentityOrganism organismEnsemblDB bioentityName designelementMapping; do
    rm -rf ${f}.log; rm -rf ${f}.bad
    sqlldr ${dbUser}/${dbPass}@${dbSID} control=${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/db/sqlldr/${f}.ctl data=${f}.dat log=${f}.log bad=${f}.bad
    if [ -s "${f}.bad" ]; then
	echo "ERROR: Failed to load ${f} into ${dbUser}@${dbSID}"
	exit 1
    fi
done

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

####################
echo "Re-build Solr index on the staging Atlas instance"
urlBase=http://${stagingServer}:8080/gxa/admin/buildIndex
# First submit Solr build
response=`curl -s -u $stagingTomcatAdmin:$stagingTomcatAdminPass "$urlBase"`
if [ -z "$response" ]; then
    echo "ERROR: Got empty response from $urlBase" >&2
    exit 1
fi 
echo $response | grep -P '^STARTED|^PROCESSING' > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Incorrect response from: $urlBase - expected: STARTED; got: '$response'" >&2
    exit 1
fi 
# Now keeping checking status every 5 mins until the process is complete; then report success and time taken
echo $response | grep '^COMPLETED' > /dev/null
while [ $? -ne 0  ]; do
    # E.g. PROCESSING, total time elapsed: 0 minutes, estimated progress: 1%, estimated minutes to completion: 35, file being processed
    echo $response | awk -F"," '{print $1","$2","$3","$4}'
    sleep 300 
    response=`curl -s -u $stagingTomcatAdmin:$stagingTomcatAdminPass "$urlBase/status"`
    echo $response | grep '^COMPLETED' > /dev/null
done
# Report success and time taken 
echo $response | awk -F"," '{print $1","$2}'

####################
echo "Rebuild the multi-term autocomplete index"
# c.f. step 3 on https://www.ebi.ac.uk/seqdb/confluence/pages/viewpage.action?title=Building+the+solr+indices&spaceKey=GXA
# First submit Solr build
response=`curl -s "http://${stagingServer}:8983/solr/gxa/suggest_properties?spellcheck.build=true"`
if [ -z "$response" ]; then
    echo "ERROR: Got empty response from http://${stagingServer}:8983/solr/gxa/suggest_properties?spellcheck.build=true" >&2
    exit 1
fi 
echo $response | grep '<int name="status">0</int>' > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Incorrect response from: http://${stagingServer}:8983/solr/gxa/suggest_properties?spellcheck.build=true - expected: <int name="status">0</int>; got: '$response'" >&2
    exit 1
else 
    echo "'http://${stagingServer}:8983/solr/gxa/suggest_properties?spellcheck.build=true' has completed successfully"
fi 

# Decorate all experiments
aux=~/tmp/decorate.$$
rm -rf $aux
for decorationType in genenames tracks R cluster gsea; do 
    echo "Decorate all experiments in ${ATLAS_PROD}/analysis with $decorationType"
    submitted=`${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/decorate_all_experiments.sh $decorationType`
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
    ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/decorate_all_experiments.sh $decorationType copyonly
done
rm -rf $aux

####################
if [ 1 -eq 0 ]; then  
# TODO: Switch off the anaytics re-build until java dev team have stabilised the build procedure

echo "Re-build Analytics index on the staging Atlas instance"
# First submit Analytics index build
urlBase=http://${stagingServer}:8080/gxa/admin/analyticsIndex/buildIndex
statusPrefix="Full Analytics index build"
response=`curl -s -u $stagingTomcatAdmin:$stagingTomcatAdminPass "$urlBase"`
if [ -z "$response" ]; then
    echo "ERROR: Got empty response from $urlBase" >&2
    exit 1
fi 
echo $response | grep "$statusPrefix started" > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Incorrect response from: $urlBase - expected: '$statusPrefix started'; got: '$response'" >&2
    exit 1
fi 
# Now keeping checking status every 30 mins until the process is complete; then report success and time taken
echo $response | tail -1 | "$statusPrefix finished" > /dev/null
while [ $? -ne 0  ]; do
    # E.g. PROCESSING, total time elapsed: 0 minutes, estimated progress: 1%, estimated minutes to completion: 35, file being processed
    numExps=`echo $response | grep 'E-' | wc -l`
    echo "Indexed $numExps experiments so far..."
    sleep 1800 
    response=`curl -s -u $stagingTomcatAdmin:$stagingTomcatAdminPass "$urlBase/status"`
    echo $response | tail -1 | grep "$statusPrefix finished" > /dev/null
done
# Report $statusPrefix finished time
echo $response | tail -1

# TODO: end
fi