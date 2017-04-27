# This script retrieves the latest mapping between Interpro ids and their types (family/domain) and terms
# Author: rpetry@ebi.ac.uk
PROJECT_ROOT=`dirname $0`/../..

outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir"  >&2
    exit 1
fi

curl -s ftp://ftp.ebi.ac.uk/pub/databases/interpro/62.0/interpro.xml.gz | zcat > $outputDir/interpro.xml
curl -s ftp://ftp.ebi.ac.uk/pub/databases/interpro/62.0/interpro.dtd > $outputDir/interpro.dtd

pushd $PROJECT_ROOT
echo "Parse the file we obtained from Interpro's FTP site"
export JAVA_OPTS=-Xmx3000M
amm -s -c "import \$file.src.interpro.Parse; Parse.main(\"$outputDir/interpro.xml\")" > $outputDir/interproIDToTypeTerm.tsv.tmp
if [ $? -ne 0 ]; then
    echo "Ammonite errored out, exiting..." >&2
    exit 1
fi
popd
echo "Regenerate Interpro files"
mv $outputDir/interproIDToTypeTerm.tsv.tmp $outputDir/interproIDToTypeTerm.tsv
cat $outputDir/interproIDToTypeTerm.tsv | awk -F"\t" '{print $2"\t"$1}' | sort -k1,1 -t$'\t' > $outputDir/interproIDToTypeTerm.tsv.decorate.aux
