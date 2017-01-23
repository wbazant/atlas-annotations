#Use me like this:
#source ./util/create_test_env.sh /var/tmp/ATLAS_PROD

export ATLAS_PROD=${1:-"/var/tmp/atlas_prod"}
REMOTE_ATLAS_PROD=ebi-005:/nfs/production3/ma/home/atlas3-production

for dir in "" archive archive/ensembl_x_y archive/wbps_z archive/reactome_ensx_y go interpro mirbase
  do mkdir -p $ATLAS_PROD/bioentity_properties/$dir
done

ln -fhs $ATLAS_PROD/bioentity_properties/archive/ensembl_x_y $ATLAS_PROD/bioentity_properties/ensembl
ln -fhs $ATLAS_PROD/bioentity_properties/archive/reactome_ensx_y $ATLAS_PROD/bioentity_properties/reactome
ln -fhs $ATLAS_PROD/bioentity_properties/archive/wbps_z $ATLAS_PROD/bioentity_properties/wbps


echo -e "GO:0019952\tGO:0000003" > $ATLAS_PROD/bioentity_properties/go/go.alternativeID2CanonicalID.tsv

scp $REMOTE_ATLAS_PROD/bioentity_properties/bioentityOrganism.dat $ATLAS_PROD/bioentity_properties/bioentityOrganism.dat


mkdir -p $ATLAS_PROD/analysis/baseline/proteomics/experiments
mkdir -p $ATLAS_PROD/analysis/baseline/rna-seq/experiments
mkdir -p $ATLAS_PROD/analysis/differential/microarray/experiments
mkdir -p $ATLAS_PROD/analysis/differential/rna-seq/experiments


scp -r $REMOTE_ATLAS_PROD/analysis/baseline/proteomics/experiments/E-PROT-1 $ATLAS_PROD/analysis/baseline/proteomics/experiments
scp -r $REMOTE_ATLAS_PROD/analysis/baseline/rna-seq/experiments/E-MTAB-513 $ATLAS_PROD/analysis/baseline/rna-seq/experiments
scp -r $REMOTE_ATLAS_PROD/analysis/differential/microarray/experiments/E-GEOD-57907 $ATLAS_PROD/analysis/differential/microarray/experiments
scp -r $REMOTE_ATLAS_PROD/analysis/differential/rna-seq/experiments/E-GEOD-54705 $ATLAS_PROD/analysis/differential/rna-seq/experiments
