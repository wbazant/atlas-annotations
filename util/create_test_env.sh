#Use me like this:
#source ./util/create_test_env.sh /var/tmp/ATLAS_PROD

export ATLAS_PROD=${1:-"/var/tmp/atlas_prod"}

for dir in "" archive archive/ensembl_x_y archive/wbps_z archive/reactome_ensx_y go interpro mirbase
  do mkdir -p $ATLAS_PROD/bioentity_properties/$dir
done

ln -fhs $ATLAS_PROD/bioentity_properties/archive/ensembl_x_y $ATLAS_PROD/bioentity_properties/ensembl
ln -fhs $ATLAS_PROD/bioentity_properties/archive/reactome_ensx_y $ATLAS_PROD/bioentity_properties/reactome
ln -fhs $ATLAS_PROD/bioentity_properties/archive/wbps_z $ATLAS_PROD/bioentity_properties/wbps
