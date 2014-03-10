#!/bin/bash
# A script to increment release numbers in annotation source config files for ensembl and ensemblgenoms to $ENSEMBL_RELNUM and $ENSEMBLGENOMES_RELNUM respectively
# After the script is run, the annotation source config files need to be commited and pushed to git, so that they are propagated to /nfs/ma/home/atlas3-production/sw/atlasprod
# Author: rpetry@ebi.ac.uk


prevEnsemblRelNum=$1
prevEnsemblGenomesRelNum=$2
newEnsemblRelNum=$3
newEnsemblGenomesRelNum=$4
annotSrcsDir=$5

if [ $# -lt 5 ]; then
        echo "Usage: $0 ENSEMBL_RELNUM ENSEMBLGENOMES_RELNUM ANNSRCS_DIR"
	echo "e.g. $0 74 21 75 21 <atlasprod clone>/bioentity_annotations/ensembl/annsrcs" 
        exit;
fi

pushd $annotSrcsDir
if [ "$newEnsemblRelNum" != "$prevEnsemblRelNum" ]; then
    for f in $(ls ); do perl -pi -e "s|software.version=${prevEnsemblRelNum}$|software.version=${newEnsemblRelNum}|" $f; done
fi
if [ "$newEnsemblGenomesRelNum" != "$prevEnsemblGenomesRelNum" ]; then
    for f in $(ls ); do perl -pi -e "s|software.version=${prevEnsemblGenomesRelNum}$|software.version=${newEnsemblGenomesRelNum}|" $f; done
fi
grep 'software\.version=' * | awk -F":" '{print $NF}'
popd