#!/bin/bash
# This script calls the Ammonite code that fetches annotations.

LOG=$ATLAS_PROD/log
mkdir -p LOG

pushd `dirname $0`/..

amm -s -c "import \$file.^.src.pipeline.main; main.runAll(\"$LOG\")" > $LOG/amm.log

popd
