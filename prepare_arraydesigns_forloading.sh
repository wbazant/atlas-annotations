# This script retrieves organisms for all bioenentities in ensembl (via ensgene) and mirbase (via hairpin) directories 
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
    exit 1
fi

out=$outputDir/designelementMapping.dat
rm -rf $out

function removeDuplicateMappigs {
    f=$1
    cp $f ${f}.original

    # Put design elements mapping to multiple genes into ${f}.duplicatemappings.aux
    tail -n +2 ${f} | sort -k 1,1 | awk '{print $2}' | sort | uniq -c | sort -k 1,1 --numeric | grep -v '^      1' | awk '{print "\t"$2}' > ${f}.duplicatemappings.aux
    # Remove all such 'duplicate' design elements from $f
    grep -Fvf ${f}.duplicatemappings.aux $f > $f.aux
    mv ${f}.aux ${f}

    # test that all design elements that map to multiple genes have in fact been removed; fail if not
    numOfDups=`cat $f | awk '{print $2}' | sort | uniq -c | sort -k 1,1 --numeric | grep -v '^      1' | wc -l`
    if [ $numOfDups != 0 ]; then
	echo "ERROR: Failed to remove duplicates from $f" >&2
	exit 1
    else
        rm -rf ${f}*.aux
        # rm -rf ${f}.original  	
    fi
}

pushd $outputDir/ensembl
for f in $(ls *A-*.tsv); do 
    echo "Removing design elements mapped to multiple genes from $f..."
    removeDuplicateMappigs $f
done

IFS="
"

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
