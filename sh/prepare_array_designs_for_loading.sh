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

if [ $# -lt 2 ]; then
  echo "Usage: $0 thirdColumnName source1 ... sourceN"
  exit 1
fi

thirdColumnName=$1
shift

IFS="
"

for f in $@; do
    arrayDesign=`basename $f | awk -F"." '{print $2}'`
    IFS=$'\t'; tail -n +2 $f | while read probeSet geneId; do
	echo -e "$geneId\t$probeSet\t${thirdColumnName}\t$arrayDesign";
    done
    IFS="
"
done
