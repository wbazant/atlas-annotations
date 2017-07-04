# This script retrieves organisms for all bioenentities in ensembl (via
# ensgene), mirbase (via hairpin), and wbps (via wbpsgene) directories
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
fi

today="`eval date +%Y-%m-%d`"
aux="/tmp/prepare_bioentityorganisms_forloading.${today}.$$.aux"
rm -rf $aux
rm -rf $outputDir/bioentityOrganism.dat

pushd $outputDir/mirbase
for f in $(ls *.mature.tsv); do echo $f | awk -F"." '{print $1}' >> $aux ; done
popd
pushd $outputDir/ensembl
for f in $(ls *.ensgene.tsv); do echo $f | awk -F"." '{print $1}' >> $aux ; done
popd
pushd $outputDir/wbps
for f in $(ls *.wbpsgene.tsv); do echo $f | awk -F"." '{print $1}' >> $aux ; done
popd

i=1
for organism in $(sort -u $aux); do
  # Upper-case the first letter and replace underscrores with spaces in organism
  prettyOrganism=`echo "$organism" | sed 's/.*/\u&/' | tr "_" " "`
  echo -e "$i\t$prettyOrganism" >> $outputDir/bioentityOrganism.dat
  i=$[$i+1]
done

# Remove auxiliary file(s)
rm -rf $aux
exit 0
