/*

The files need to go somewhere.

You should also be able to verify that the task happened by looking in the filesystem.

It would be really nice if they depended on system variables.

Should play nicely with mergePropertiesIntoMatrix.pl which requires as follows:
"""
There are some assumption on the input directory:
   - it contains only files with bioentity annotations (for a given property, for a given bioentity and for a given organism)
   - file names are expected to be <species>.<bioentity>.<property>.tsv
"""
ATLAS_FTP=/ebi/ftp/pub/databases/microarray/data/atlas
ATLAS_EXPS=/nfs/public/ro/fg/atlas/experiments

##CODE+ANNOTATIONS

##LOGS

##DATA
ATLAS_PROD=/nfs/production3/ma/home/atlas3-production

bioentity_properties_out = ATLAS_PROD/bioentity_properties

bioentity_properties_out/archive
bioentity_properties_out/ensembl
bioentity_properties_out/wbps
bioentity_properties_out/go
bioentity_properties_out/interpro
bioentity_properties_out/reactome


go



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

pushd $ATLAS_PROD}/bioentity_properties/wbps
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
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/fetchAllEnsemblMappings.sh ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/annsrcs . > ~/tmp/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_bioentity_properties_update.log 2>&1
popd

pushd $ATLAS_PROD}/bioentity_properties/wbps
echo "Obtain all the individual mapping files from WBPS"
${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/wbps/fetchAllWbpsMappings.sh ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/wbps/annsrcs . > ~/tmp/ensembl_${NEW_ENSEMBL_REL}_${NEW_ENSEMBLGENOMES_REL}_wbps_${NEW_WBPS_REL}_bioentity_properties_update.log 2>&1
popd

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

echo "Merge all individual Ensembl property files into matrices"
for species in $(ls *ens*.tsv | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in ensgene enstranscript ensprotein; do
        ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/mergePropertiesIntoMatrix.pl -indir . -species $species -bioentity $bioentity -outdir .
    done
done

# Do the same for WBPS.
echo "Merge all individual WBPS property files into matrics"
for species in $(ls *wbps*.tsv | awk -F"." '{print $1}' | sort | uniq); do
    for bioentity in wbpsgene wbpsprotein wbpstranscript; do
        ${ATLAS_PROD}/sw/atlasinstall_${atlasEnv}/atlasprod/bioentity_annotations/ensembl/mergePropertiesIntoMatrix.pl -indir . -species $species -bioentity $bioentity -outdir .
    done
done
*/
