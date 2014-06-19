# This script retrieves the latest mapping between Interpro ids and their types (family/domain) and terms
# Author: rpetry@ebi.ac.uk

IFS="
"
outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir"  >&2
    exit 1
fi

f=interpro.xml
pushd $outputDir
rm -rf ${f}*
wget -P . -L ftp://ftp.ebi.ac.uk/pub/databases/interpro/${f}.gz
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to retrieve: $f" >&2 
   exit 1
fi
gunzip $f.gz
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to unzip: $f.gz" >&2 
   exit 1
fi

# Retrieve id's/types and terms separately, then (with the assumption they come back in the same order as each other)
# join by line number; then loose the line number
xml_grep interpro/name interpro.xml --text_only | grep '' -n > interpro.term.aux

for l in $(grep -P '<interpro id=' interpro.xml); do
    export s=$l
    id=`perl -e 'my $str=$ENV{'s'} =~ /\<interpro id=\"(IPR\d+)\"/; print $1'`
    type=`perl -e 'my $str=$ENV{'s'} =~ /type=\"(\w+)\"/; print $1'`
    echo -e "$id\t$type"  
done | grep '' -n > interpro.id.type.aux
perl -pi -e 's|(^\d+):|$1\t|g' interpro.term.aux
perl -pi -e 's|(^\d+):|$1\t|g' interpro.id.type.aux
join -t $'\t' -1 1 -2 1 interpro.term.aux interpro.id.type.aux | awk -F"\t" '{print $2"\t"$3"\t"$4}' > interproIDToTypeTerm.tsv

rm -rf interpro.*.aux
popd