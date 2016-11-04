#!/bin/bash
# A script to validate annotation sources against Ensembl(Genomes) release numbers specified in software.version field of each annotation source 
# Author: rpetry@ebi.ac.uk

annSrcsDir=$1
if [[ -z "$annSrcsDir" ]]; then
    echo "Usage: annSrcsDir" >&2
    exit 1
fi

pushd $annSrcsDir

errors=""
nl=$'\n'
# Tidy up files from previous validation
rm *.ensemblproperties
rm *.registry
for f in $(ls ); do
    echo "Validating $f..."
    url=`grep '^url=' $f | awk -F"=" '{print $NF}'`
    datasetName=`grep '^datasetName=' $f | awk -F"=" '{print $NF}'`
    softwareName=`grep '^software.name=' $f | awk -F"=" '{print $NF}'`
    softwareVersion=`grep '^software.version=' $f | awk -F"=" '{print $NF}'`
    mySqlDbName=`grep '^mySqlDbName=' $f | awk -F"=" '{print $NF}'`
    mySqlDbUrl=`grep '^mySqlDbUrl=' $f | awk -F"=" '{print $NF}'`
    mySqlDbHost=`echo $mySqlDbUrl | awk -F":" '{print $1}'`
    mySqlDbPort=`echo $mySqlDbUrl | awk -F":" '{print $2}'`
    # Get properties and registries for ensembl, plants, metazoa and fungi from Enmble biomarts
    curl -s -X GET "${url}type=attributes&dataset=${datasetName}" | awk '{print $1}' | sort | uniq > ${f}.ensemblproperties   
    curl -s -X GET "${url}type=registry" | grep database=\"${softwareName}_mart_${softwareVersion} | tr " " "\n" > ${softwareName}.registry
    mart=`grep 'name=' ${softwareName}.registry | awk -F"=" '{print $NF}' | tr -d '\"'`
    # Check that $datasetName is available in $mart
    found=`curl -s -X GET "${url}type=datasets&mart=${mart}" | awk '{print $2}' | sort | uniq | grep ${datasetName} | wc -l`
    if [ $found -ne 1 ]; then
       errors="$errors${nl}ERROR: Failed to find ${datasetName} in ${url}type=datasets&mart=${mart}"
    fi
    # Check that $mySqlDbName is present in $mySqlDbUrl for release $softwareVersion
    if [[ $annSrcsDir =~ ensembl ]]; then
        if [ -z $mySqlDbHost ]; then
            continue
        fi
        dbInfo=`mysql -s -u anonymous -h $mySqlDbHost -P $mySqlDbPort -e "SHOW DATABASES LIKE '${mySqlDbName}_core_${softwareVersion}%';"`
    elif [[ $annSrcsDir =~ wbps ]]; then
        dbInfo=`mysql -s -u ensro -h $mySqlDbHost -P $mySqlDbPort -e "SHOW DATABASES LIKE '${mySqlDbName}_core_${softwareVersion}%';"`
    else
        echo "Unrecognised annotation database in $annSrcsDir"
        exit 1
    fi
    
    if [ -z $dbInfo ]; then
        continue
    fi

    found=`echo $dbInfo | grep "^${mySqlDbName}_core_${softwareVersion}" | wc -l`
    if [ $found -ne 1 ]; then
       errors="$errors${nl}ERROR: mySQL query returned 0 results."
    fi 
    # Get ensembl properties and array designs in ansrc and report any differences
    grep -P '^property|arrayDesign\.'  $f | awk -F"=" '{print $NF}' | tr "," "\n" | sort | uniq > ${f}.annsrc.ensemblproperties
    numberOfPropsInAnnSrcAndNotInEnsembl=`comm -2 -3 ${f}.annsrc.ensemblproperties ${f}.ensemblproperties | wc -l`
    if [ $numberOfPropsInAnnSrcAndNotInEnsembl -ne 0 ]; then
       errors="$errors${nl}ERROR: The following properties were not found in Ensembl for $f:${nl}"`comm -2 -3 ${f}.annsrc.ensemblproperties ${f}.ensemblproperties`
    else
	rm -f ${f}.ensemblproperties
	rm -f ${f}.annsrc.ensemblproperties
    fi
done

if [ -z "$errors" ]; then
    echo "All annotation sources validate successfully against Ensembl"    
else
    echo "The following validation errors occurred:"  >&2
    echo "$errors"  >&2
    exit 1 
fi
popd
 
