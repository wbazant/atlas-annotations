#!/bin/bash

# This script downloads, cleans up and coverts to gff3 format the gtf files as defined in the atlasprod/irap/gxa_references.conf

if [ $# -lt 3 ]; then
  echo "Usage: $0 ENSEMBL_REL ENSEMBLGENOMES_REL WBPS"
  echo "e.g. $0 85 33 7"
  exit 1
fi

ENSEMBL_REL=$1
ENSEMBLGENOMES_REL=$2
WBPS_REL=$3

# The template to slot release numbers into
gxaRefsTemplate=$(dirname ${BASH_SOURCE[0]})/gxa_references.conf
# The config file that will be used for the actual download of the gtf files
gxaRefs=~/tmp/gxa_references.conf.`eval date +%Y-%m-%d`.$$
grep "ftp.ensemblgenomes.org" $gxaRefsTemplate | perl -p -e "s|RELNO|$ENSEMBLGENOMES_REL|g" > $gxaRefs
grep "wormbase" $gxaRefsTemplate | perl -p -e "s|RELNO|$WBPS_REL|g" >> $gxaRefs
grep "ftp.ensembl.org" $gxaRefsTemplate | perl -p -e "s|RELNO|$ENSEMBL_REL|g" >> $gxaRefs

# Directory in which all gtfs/gff3 files
gtfsDir=$ATLAS_PROD/gtfs

# Download gtfs specified in $gxaRefs
while read -r organism gtf; do
    localGtf="${gtfsDir}/${organism}/"`echo $gtf | awk -F"/" '{print $NF}' | sed 's|.gz$||'`
    # Clean up any previous files for $organism, prior to downloading new ones
    mkdir -p ${gtfsDir}/${organism}
    rm -rf ${gtfsDir}/${organism}/*
    # Download $gtf
    curl $gtf > $localGtf.gz
    if [ $? -ne 0 ]; then
	echo "ERROR: failed to fetch: $gtf" >&2
	exit 1
    fi

    # Convert gtf to gff3
    gunzip -c $localGtf.gz > $localGtf

    # Convert gtf to gff3 for the downstream bedGraph file generation for Atlas
    $(dirname ${BASH_SOURCE[0]})/gtf2gff3.pl $localGtf > `echo $localGtf | sed 's|.gtf$|.gff3|'`
    if [ $? -ne 0 ]; then
	echo "ERROR: Failed to convert: $localGtf to gff3" >&2
	exit 1
    fi
done < $gxaRefs
