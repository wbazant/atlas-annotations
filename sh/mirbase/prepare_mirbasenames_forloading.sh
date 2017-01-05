# This script generates sqlloader file for bioentity_name table, containing miRBase miRNAs, using $dir/../bioentityOrganisms.dat as the organism reference

dir="${ATLAS_PROD}/bioentity_properties/mirbase"

IFS="
"
pushd $dir
rm -rf miRNAName.dat
for f in $(ls *.*.tsv | grep -P 'mature|hairpin'); do
    prettyOrganism=`echo $f | awk -F"." '{print $1}' | sed 's/.*/\u&/' | tr "_" " "`
    type=`echo $f | awk -F"." '{print $2}'`"_miRNA"
    organismId=`grep "${prettyOrganism}$" $dir/../bioentityOrganism.dat | awk -F"\t" '{print $1}'`
    IFS=$'\t'
    tail -n +2 $f | while read identifier ignore name ignore ignore ignore; do 
	echo -e "${identifier}\t${organismId}\t${type}\t${name}"
    done 
    IFS="
"
done > miRNAName.dat
popd
exit 0
