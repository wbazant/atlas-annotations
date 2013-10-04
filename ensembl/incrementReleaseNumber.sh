#!/bin/bash
# A script to increment release numbers in annotation source config files for ensembl and ensemblgenoms to $ENSEMBL_RELNUM and $ENSEMBLGENOMES_RELNUM respectively
# After the script is run, the annotation source config files need to be commited and pushed to git, so that they are propagated to /nfs/ma/home/atlas3-production/sw/atlasprod
# Author: rpetry@ebi.ac.uk

ENSEMBL_RELNUM=$1
ENSEMBLGENOMES_RELNUM=$2
ANNSRCS_DIR=$3

if [ $# -lt 3 ]; then
        echo "Usage: $0 ENSEMBL_RELNUM ENSEMBLGENOMES_RELNUM ANNSRCS_DIR"
	echo "e.g. $0 73 20 <atlasprod clone>/bioentity_annotations/ensembl/annsrcs" 
        exit;
fi

pushd $ANNSRCS_DIR

prev_ensembl_relnum=$((ENSEMBL_RELNUM - 1))
prev_ensemblgenomes_relnum=$((ENSEMBLGENOMES_RELNUM - 1))

for f in $(ls ); do perl -pi -e "s|software.version=${prev_ensembl_relnum}$|software.version=${ENSEMBL_RELNUM}|" $f; done
for f in $(ls ); do perl -pi -e "s|software.version=${prev_ensemblgenomes_relnum}$|software.version=${ENSEMBLGENOMES_RELNUM}|" $f; done
grep 'software\.version=' * | awk -F":" '{print $NF}'
popd