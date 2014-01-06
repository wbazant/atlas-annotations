# This script geneartes sqlloader file for bioentity_name table, containing miRBase miRNAs, using $dir/../bioentityOrganisms.dat as the organism reference

dir="/nfs/ma/home/atlas3-production/bioentity_properties/mirbase"

IFS="
"
pushd $dir
rm -rf miRNAName.dat
for f in $(ls *.*.tsv | grep -P 'mature|hairpin'); do
    prettyOrganism=`echo $f | awk -F"." '{print $1}' | sed 's/.*/\u&/' | tr "_" " "`
    type=`echo $f | awk -F"." '{print $2}'`"_miRNA"
    organismId=`grep "${prettyOrganism}$" $dir/../bioentityOrganism.dat | awk -F"\t" '{print $1}'`
    # Skip lines when no mapping for gene identifier exists
    for l in $(tail -n +2 $f); do
	identifier=`echo $l | awk -F"\t" '{print $1}'`
	symbol=`echo $l | awk -F"\t" '{print $3}'`
	echo -e "${identifier}\t${organismId}\t${type}\t${symbol}" >> miRNAName.dat
    done
done
popd
exit 0
