# This script retrieves organisms for all bioenentities in ensembl (via ensgene) and mirbase (via hairpin) directories 
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
    exit 1
fi

out=$outputDir/designelementMapping.dat
rm -rf $out

pushd $outputDir/ensembl
for f in $(ls *A-*.tsv); do 
    echo "Removing design elements mapped to multiple genes from $f..."
    head -1 $f > ${f}.aux
    scala ${ATLAS_PROD}/sw/atlasinstall_prod/atlasprod/bioentity_annotations/ProbesetToMultipleGenesEliminator.scala $f >> ${f}.aux
    mv ${f}.aux ${f}
done

IFS="
"
for f in $(ls *A-*.tsv); do 
    arrayDesign=`echo $f | awk -F"." '{print $2}'`
    echo "Processing $f..."
    IFS=$'\t'; tail -n +2 $f | while read probeSet geneId; do    
	echo -e "$geneId\t$probeSet\tgene\t$arrayDesign"; 
    done >> $out
    IFS="
"
done
popd

pushd $outputDir/mirbase
for f in $(ls *A-*.tsv); do 
    arrayDesign=`echo $f | awk -F"." '{print $2}'`
    echo "Processing $f..."
    IFS=$'\t'; tail -n +2 $f | while read probeSet geneId; do    
	echo -e "$geneId\t$probeSet\tmature_miRNA\t$arrayDesign"; 
    done >> $out
    IFS="
"
done 
popd

exit 0
