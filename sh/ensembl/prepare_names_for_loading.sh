#!/bin/bash
# This script geneartes sqlloader content for bioentity_name table, containing Ensmebl genes
# $1 organismReference - lines like:
### 1	Acacia auriculiformis
### 2	Acacia mangium
### 3	Acyrthosiphon pisum
# $n - file in - lines like:
### ENSGALG00000000003	PANX2
### ENSGALG00000000004
### ENSGALG00000000011	C10orf88
# stdout: lines like:
### ENSAPLG00000011139	8	gene	PIK3AP1
### ENSAPLG00000011140	8	gene
### ENSAPLG00000011141	8	gene	CHD2

if [ $# -lt 2 ]; then
  echo "Usage: $0 organismReference source1 ... sourceN"
  exit 1
fi

organismReference=$1
shift

IFS="
"
for f in $@; do
  prettyOrganism=`basename $f | awk -F"." '{print $1}' | tr "_" " "`
  organismId=`grep -i "${prettyOrganism}$" $organismReference | awk -F"\t" '{print $1}'`
  if [ -z "$organismId" ]; then
	echo "ERROR: Could not retrieve organismid for '$prettyOrganism'" >&2
	exit 1
  fi

  IFS=$'\t'
  cat $f | while read identifier name #danger - the lines could have n elements, only this particular mapping has one or two
  do
	if [ ! -z "$name" ]; then
	    echo -e "${identifier}\t${organismId}\tgene\t${name}"
	else
	    echo -e "${identifier}\t${organismId}\tgene"
	fi
  done
    IFS="
"
done
