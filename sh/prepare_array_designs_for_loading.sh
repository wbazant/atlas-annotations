#!/bin/bash
# This script geneartes sqlloader content for <some DB table>
# $1 name of third column - "gene" or "mature_miRNA"
# $n - file in - lines like:
### Bt.9082.1.S1_at   ENSBTAG00000016312
### Bt.24457.1.S1_at
# stdout: lines like:
### Bt.9082.1.S1_at   ENSBTAG00000016312
### ENSAPLG00000011140	8	gene
### ENSAPLG00000011141	8	gene	CHD2

# out: gene id \t probe set \t gene/mirna \t array design
function probesFromFile() {
  idType=$1
  filePath=$2
  arrayDesign=$(basename $filePath | cut -f 2 -d ".")
  grep -E "^\w+\t\w+" $filePath | awk -v idType=$1 -v arrayDesign=$arrayDesign -F '\t' '{print $2"\t"$1"\t"idType"\t"arrayDesign}'
}

if [ $# -lt 2 ]; then
  echo "Usage: $0 thirdColumnName source1 ... sourceN"
  exit 1
fi

thirdColumnName=$1
shift

for f in $@; do
  probesFromFile $thirdColumnName $f
done
