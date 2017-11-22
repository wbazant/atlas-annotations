#!/bin/bash

# Source script from the same (prod or test) Atlas environment as this script
scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${scriptDir}/experiment_loading_routines.sh
atlasEnv=`atlas_env`

## checking if the pipeline is switch off or on

