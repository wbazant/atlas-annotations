#!/bin/bash
# I used to source this script from the same (prod or test) Atlas environment as this script
# scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ../generic_routines.sh
atlasEnv=`atlas_env`

# quit if not prod user
check_prod_user
if [ $? -ne 0 ]; then
    exit 1
fi

if [ $# -lt 2 ]; then
  echo "Usage: $0 dbUser dbSID"
  echo "e.g. $0 atlasprd3 ATLASPRO"
  exit 1
fi


dbUser=$1
dbSID=$2

dbPass=`get_pass $dbUser`
dbConnection=${dbUser}/${dbPass}@${dbSID}



echo "Clear previous Ensembl data from the public all subdirs of ${ATLAS_FTP}/bioentity_properties"
for dir in ensembl mirbase reactome go interpro wbps; do
   rm -rf ${ATLAS_FTP}/bioentity_properties/${dir}/*
done

echo "Copy all array design mapping files into the public Ensembl data directory (this directory is used only for Solr index build)"
cp ${ATLAS_PROD}/bioentity_properties/ensembl/*.A-*.tsv ${ATLAS_FTP}/bioentity_properties/ensembl/


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


echo "Copy all files to the other public data directories"
for dir in mirbase reactome go interpro; do
       cp ${dir}/*.tsv ${ATLAS_FTP}/bioentity_properties/${dir}/
done
popd
