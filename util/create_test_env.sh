#Use me like this:
#source ./util/create_test_env.sh /var/tmp/ATLAS_PROD

export ATLAS_PROD=${1:-"/var/tmp/atlas_prod"}

for dir in "" archive ensembl go interpro mirbase reactome wbps
  do mkdir -p $ATLAS_PROD/bioentity_properties/$dir
done
