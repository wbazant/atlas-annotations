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
    cp $f ${f}.original

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
        # rm -rf ${f}.original  	
    fi
}

pushd $outputDir/ensembl
for f in $(ls *A-*.tsv); do 
    echo "Removing desingn elements mapped to multiple genes from $f..."
    removeDuplicateMappigs $f
done

for f in $(ls *A-*.tsv); do 
    arrayDesign=`echo $f | awk -F"." '{print $2}'`
    for l in $(tail -n +2 $f); do
	designElementIdentifierType=`echo $l | awk -F"\t" '{print $2"\t"$1"\tgene"}'`
	echo -e "${designElementIdentifierType}\t${arrayDesign}" >> $out
    done
done
popd

pushd $outputDir/mirbase
for f in $(ls *A-*.tsv); do 
    arrayDesign=`echo $f | awk -F"." '{print $2}'`
    for l in $(tail -n +2 $f); do
        designElementIdentifierType=`echo $l | awk -F"\t" '{print $2"\t"$1"\tmature_miRNA"}'`
	echo -e "${designElementIdentifierType}\t${arrayDesign}" >> $out
    done
done 
popd

exit 0
