#!/bin/bash

PROJECT_ROOT=`dirname $0`/../..

function fetchGeneSynonyms {
    annSrc=$1
    mySqlDbHost=$2
    mySqlDbPort=$3
    mySqlDbName=$4
    softwareVersion=$5
    annotator=$6    # This is either ensembl or wbps

    if [[ $annotator =~ ensembl ]]; then
        dbUser=anonymous
    elif [[ $annotator =~ wbps ]]; then
        dbUser=ensro
    else
        echo "ERROR: for $annSrc: unknown annotator: $annotator" >&2
        exit 1
    fi

    latestReleaseDB=`mysql -s -u $dbUser -h "$mySqlDbHost" -P "$mySqlDbPort" -e "SHOW DATABASES LIKE '${mySqlDbName}_core_${softwareVersion}%'" | grep "^${mySqlDbName}_core_${softwareVersion}"`
    if [ -z "$latestReleaseDB" ]; then
        echo "ERROR: for $annSrc: Failed to retrieve the database name for release number: $softwareVersion" >&2
        exit 1
    else
        mysql -s -u $dbUser -h $mySqlDbHost -P $mySqlDbPort -e "use ${latestReleaseDB}; SELECT DISTINCT gene.stable_id, external_synonym.synonym FROM gene, xref, external_synonym WHERE gene.display_xref_id = xref.xref_id AND external_synonym.xref_id = xref.xref_id ORDER BY gene.stable_id" | sort -k 1,1
    fi
}

for path in $(find $PROJECT_ROOT/annsrcs -type f) ; do
  organism=$(basename $path)
  annSrcsDir=$(basename $(dirname $path))
  if [[ $annSrcsDir =~ ensembl ]]; then
      target=$ATLAS_PROD/bioentity_properties/${annSrcsDir}/${organism}.ensgene.synonym.tsv
  elif [[ $annSrcsDir =~ wbps ]]; then
      target=$ATLAS_PROD/bioentity_properties/${annSrcsDir}/${organism}.wbpsgene.synonym.tsv
  else
      echo "ERROR: for $annSrc: neither ensembl or wbps" >&2
      exit 1
  fi
  softwareVersion=`grep '^software.version=' $path | awk -F"=" '{print $NF}'`
  mySqlDbName=`grep '^mySqlDbName=' $path | awk -F"=" '{print $NF}'`
  mySqlDbUrl=`grep '^mySqlDbUrl=' $path | awk -F"=" '{print $NF}'`
  if [ ! -z "$mySqlDbUrl" ] ; then
    mySqlDbHost=`echo $mySqlDbUrl | awk -F":" '{print $1}'`
    mySqlDbPort=`echo $mySqlDbUrl | awk -F":" '{print $2}'`
    echo `date` " fetching gene synonyms: " $organism $mySqlDbHost $mySqlDbPort $mySqlDbName $softwareVersion $annSrcsDir
    fetchGeneSynonyms $organism $mySqlDbHost $mySqlDbPort $mySqlDbName $softwareVersion $annSrcsDir > $target
  else
    echo "Skipping: " $path
  fi
done
