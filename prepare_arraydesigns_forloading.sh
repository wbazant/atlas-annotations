# This script retrieves organisms for all bioenentities in ensembl (via ensgene) and mirbase (via hairpin) directories 
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "[ERROR] Usage: outputDir"
fi

out=$outputDir/designelementMapping.dat
rm -rf $out

IFS="
"

pushd $outputDir/ensembl
type="gene"
for f in $(ls *A-*.tsv); do 
    arrayDesign=`echo $f | awk -F"." '{print $2}'`
    for l in $(tail -n +2 $f); do
	identifier=`echo $l | awk -F"\t" '{print $1}'`
	designElement=`echo $l | awk -F"\t" '{print $2}'`
	echo -e "${designElement}\t${identifier}\t${type}\t${arrayDesign}" >> $out
    done
done
popd

pushd $outputDir/mirbase
type="mature_miRNA"
for f in $(ls *A-*.tsv); do 
    arrayDesign=`echo $f | awk -F"." '{print $2}'`
    for l in $(tail -n +2 $f); do
        identifier=`echo $l | awk -F"\t" '{print $1}'`
        designElement=`echo $l | awk -F"\t" '{print $2}'`
        echo -e "${designElement}\t${identifier}\t${type}\t${arrayDesign}" >> $out
    done
done 
popd

exit 0
