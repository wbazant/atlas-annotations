#!/bin/bash
# A wrapper script to update all array designs in the current directory to the latest miRBase release
# Author: rpetry@ebi.ac.uk

pushd /nfs/ma/home/atlas3-production/arraydesigns/microRNA

wget ftp://anonymous:anonymous\@mirbase.org/pub/mirbase/CURRENT/aliases.txt.gz
gunzip aliases.txt.gz

mirna_arraydesigns_to_mirbase.pl -m aliases.txt

mv aliases.txt miRBase
popd
