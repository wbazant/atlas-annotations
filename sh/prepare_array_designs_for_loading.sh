#!/bin/bash
# This script geneartes sqlloader content for <some DB table>
# $n - file in - lines like:
### Bt.9082.1.S1_at   ENSBTAG00000016312
### Bt.24457.1.S1_at
# stdout: lines like:
### Bt.9082.1.S1_at   ENSBTAG00000016312
### ENSAPLG00000011140	8	gene
### ENSAPLG00000011141	8	gene	CHD2

# out: gene id \t probe set \t gene/mirna \t array design
function probesFromFile() {
  filePath=$1
  if (head -n 2 $filePath | grep "MIMAT" > /dev/null) ; then
      idType="mature_miRNA"
  else
      idType="gene"
  fi

  arrayDesign=$(basename $filePath | cut -f 2 -d ".")
  grep -E "^\w+[[:space:]]\w+" $filePath | awk -v idType=$idType -v arrayDesign=$arrayDesign -F '\t' '{print $2"\t"$1"\t"idType"\t"arrayDesign}'
}

if [ $# -lt 1 ]; then
  echo "Usage: $0 source1 ... sourceN" >&2
  exit 1
fi

for f in $@; do
  probesFromFile $f
done
