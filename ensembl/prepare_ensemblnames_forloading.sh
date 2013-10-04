# This script geneartes sqlloader file for bioentity_name table, containing Ensmebl genes, using $dir/../bioentityOrganisms.dat as the organism reference

dir="/nfs/ma/home/atlas3-production/bioentity_properties/ensembl"

IFS="
"
pushd $dir
out=geneName.dat
rm -rf $out
for f in $(ls *.ensgene.symbol.tsv); do
    prettyOrganism=`echo $f | awk -F"." '{print $1}' | sed 's/.*/\u&/' | tr "_" " "`
    organismId=`grep "${prettyOrganism}$" $dir/../bioentityOrganism.dat | awk -F"\t" '{print $1}'`
    # Skip lines when no mapping for gene identifier exists
    for l in $(cat $f); do
	identifier=`echo $l | awk -F"\t" '{print $1}'`
	name=`echo $l | awk -F"\t" '{print $2}'`
	if [ ! -z "$name" ]; then
	   echo -e "${identifier}\t${organismId}\tgene\t${name}" >> $out
	else
	   echo -e "${identifier}\t${organismId}\tgene" >> $out
	fi 
    done
done
popd
exit 0
