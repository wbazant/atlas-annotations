# This script retrieves organisms for all bioenentities in ensembl (via ensgene) and mirbase (via hairpin) directories 
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "[ERROR] Usage: outputDir"
    exit 1
fi

out=$outputDir/designelementMapping.dat
rm -rf $out

IFS="
"

function removeDuplicateMappigs {
    f=$1
    mv $f ${f}.original

    echo "Processing $f..."
    tail -n +2 ${f} | sort -k 1 | sort > ${f}.aux
    cat ${f}.aux | awk '{print $2}' | sort | uniq -c | sort -k 1 --numeric | grep -v '^      1' | awk '{print $2}' | xargs -I % grep '%$' ${f}.aux | sort -k 1 > ${f}.duplicatemappings.aux
    head -1 ${f}.original > $f
    comm -3 ${f}.aux ${f}.duplicatemappings.aux | grep -v -P '^\t' >> $f

    # test that all design elements that map to multiple genes have in fact been removed; fail if not
    numOfDups=`cat $f | awk '{print $2}' | sort | uniq -c | sort -k 1 --numeric | grep -v '^      1' | wc -l`
    if [ $numOfDups != 0 ]; then
	echo "ERROR: Failed to remove duplicates from $f"
	exit 1
    else
        rm -rf ${f}*.aux
        # rm -rf ${f}  	
    fi
}

pushd $outputDir/ensembl
type="gene"
for f in $(ls *A-*.tsv); do 
    removeDuplicateMappigs $f
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
