#!/bin/bash
# This script retrieves all miRBase mature miRNA and stem-loop sequence properties
# Author: rpetry@ebi.ac.uk

arrayDesign=$1
outputDir=$2
if [[ -z "$arrayDesign" || -z "$outputDir" ]]; then
    echo "Usage: $0 arrayDesign outputDir" >&2
    exit 1
fi

if [ ! -e  ${outputDir}/idprefix_to_organism.tsv ]; then
    echo "ERROR: ${outputDir}/idprefix_to_organism.txt does not exist" >&2
    exit 1
fi

IFS="
"
adFile="${ATLAS_PROD}/arraydesigns/microRNA/$arrayDesign/$arrayDesign.tsv"
for l in $(tail -n +2 $adFile); do
    prefix=`echo $l | awk -F"-" '{print $1}'`
    organism=`grep "^$prefix" ${outputDir}/idprefix_to_organism.txt | awk -F"\t" '{print $NF}'`
    if [ ! -e  ${outputDir}/${organism}.${arrayDesign}.tsv ]; then
	head -1 $adFile > ${outputDir}/${organism}.${arrayDesign}.tsv
    fi
    echo $l >> ${outputDir}/${organism}.${arrayDesign}.tsv
done


exit 0



