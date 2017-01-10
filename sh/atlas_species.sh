#!/bin/bash
# This script creates the species file for Expression Atlas based on bioentity annotations

target=${1:-`pwd`/speciesProperties.json}

pushd `dirname $0`

amm -s -c 'import $file.^.src.atlas.AtlasSpecies; AtlasSpecies.dump()' > $target

if [ -s $target ]
then
  echo "Generated species file at " $target
else
  rm $target
fi

popd
