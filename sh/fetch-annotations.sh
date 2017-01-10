#!/bin/bash
# This script calls the Ammonite code that fetches annotations.

pushd `dirname $0`/..

amm -s -c 'import $file.src.pipeline.main; main.runAll()'

popd
