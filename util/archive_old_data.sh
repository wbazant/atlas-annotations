if [ $# -lt 3 ]; then
  echo "Usage: $0 OLD_ENSEMBL_REL OLD_ENSEMBLGENOMES_REL OLD_WBPS_REL"
  echo "e.g. $0 85 33 7 86 34 8"
  exit 1
fi

OLD_ENSEMBL_REL=$1
OLD_ENSEMBLGENOMES_REL=$2
OLD_WBPS_REL=$3

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
