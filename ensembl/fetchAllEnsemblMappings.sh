#!/bin/bash
# This script retrieves all properties for each bioentity type for each annotation source config file defined in ${annSrcsDir}/ 
# Author: rpetry@ebi.ac.uk


# Get directory containing annotation source files and the output directory for bioentity property output files
annSrcsDir=$1
outputDir=$2
if [[ -z "$annSrcsDir" || -z "$outputDir" ]]; then
    echo "Usage: annSrcsDir outputDir" >&2
    exit 1
fi


# Fetch properties for ensemblProperty1 and (optionally) ensemblProperty2 from the Ensembl biomart identified by url, serverVirtualSchema and datasetName)
function fetchProperties {
    url=$1
    serverVirtualSchema=$2
    datasetName=$3
    ensemblProperty1=$4
    ensemblProperty2=$5
    chromosomeName=$6

    if [[ -z "$url" || -z "$serverVirtualSchema" || -z "$datasetName" || -z "$ensemblProperty1" ]]; then
	echo "ERROR: Usage: url serverVirtualSchema datasetName ensemblProperty1 (ensemblProperty2)" >&2
	exit 1
    fi

    if [ ! -z "$chromosomeName" ]; then
	chromosomeFilter="<Filter name = \"chromosome_name\" value = \"${chromosomeName}\"/>"
    else
	chromosomeFilter=""
    fi

    query="query=<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE Query><Query virtualSchemaName = \"${serverVirtualSchema}\" formatter = \"TSV\" header = \"1\" uniqueRows = \"1\" count = \"0\" ><Dataset name = \"${datasetName}\" interface = \"default\" >${chromosomeFilter}<Attribute name = \"${ensemblProperty1}\" />"
    if [ ! -z "$ensemblProperty2" ]; then
	query="$query<Attribute name = \"${ensemblProperty2}\" />"
    fi
    # In some cases a line '^\t$ensemblProperty2' is being returned (with $ensemblProperty1 missing), e.g. in the following call:
    #curl -s -G -X GET --data-urlencode 'query=<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE Query><Query virtualSchemaName = "metazoa_mart_19" formatter = "TSV" header = "1" uniqueRows = "1" count = "0" ><Dataset name = "agambiae_eg_gene" interface = "default" >${chromosomeFilter} <Attribute name = "ensembl_peptide_id" /><Attribute name = "description" /></Dataset></Query>' "http://metazoa.ensembl.org/biomart/martservice" | grep AGAP005154
    # Until this is clarified, skip such lines with grep -vP '^\t'
    curl -s -G -X GET --data-urlencode "$query</Dataset></Query>" "$url" | tail -n +2 | sort -k 1,1 | grep -vP '^\t'
    # echo "curl -s -G -X GET --data-urlencode \"$query</Dataset></Query>\" \"$url\" | tail -n +2 | sort -k 1,1" > /dev/stderr
}

function fetchGeneSynonyms {
    annSrc=$1
    mySqlDbHost=$2
    mySqlDbPort=$3
    mySqlDbName=$4
    softwareVersion=$5
    latestReleaseDB=`mysql -s -u anonymous -h "$mySqlDbHost" -P "$mySqlDbPort" -e "SHOW DATABASES LIKE '${mySqlDbName}_core_${softwareVersion}%'" | grep "^${mySqlDbName}_core_${softwareVersion}"`
    if [ -z "$latestReleaseDB" ]; then
	echo "ERROR: for $annSrc: Failed to retrieve then database name for release number: $softwareVersion" >&2
	exit 1
    else 
        mysql -s -u anonymous -h $mySqlDbHost -P $mySqlDbPort -e "use ${latestReleaseDB}; SELECT DISTINCT gene.stable_id, external_synonym.synonym FROM gene, xref, external_synonym WHERE gene.display_xref_id = xref.xref_id AND external_synonym.xref_id = xref.xref_id ORDER BY gene.stable_id" | sort -k 1,1
    fi 
}

for organism in $(ls ${annSrcsDir}/); do
    # Get all the necessary data for retrieval of mappings from the annotation source config file: 
    # ${annSrcsDir}/$organism and the associated registry settings
    url=`grep '^url=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr -d "?"`
    datasetName=`grep '^datasetName=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    softwareName=`grep '^software.name=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    softwareVersion=`grep '^software.version=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    mySqlDbName=`grep '^mySqlDbName=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    mySqlDbUrl=`grep '^mySqlDbUrl=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    mySqlDbHost=`echo $mySqlDbUrl | awk -F":" '{print $1}'`
    mySqlDbPort=`echo $mySqlDbUrl | awk -F":" '{print $2}'`
    atlasBioentityTypes=`grep '^types=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr "," " "`
    chromosomeName=`grep '^chromosomeName=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`

    registry=~/tmp/${softwareName}.registry.$$
    curl -s -X GET "${url}?type=registry" | grep "database=\"${softwareName}_mart_${softwareVersion}" | tr " " "\n" > $registry
    mart=`grep 'name=' $registry | awk -F"=" '{print $NF}' | tr -d '\"'`
    serverVirtualSchema=`grep 'serverVirtualSchema=' $registry | awk -F"=" '{print $NF}' | tr -d '\"'`
    # Retrieve property values for each Ensembl bioentity in turn
    for atlasBioentityType in $atlasBioentityTypes; do

       ensemblBioentityType=`grep "^property.${atlasBioentityType}=" ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr "," " "`
       # Iterate through all properties and retrieve values for each in turn (exclude bioentity type properties)
       for atlasProperty in `grep "^property\." ${annSrcsDir}/$organism | awk -F"=" '{print $1}' | awk -F"." '{print $2}'`; do       
          # Omit each property in $atlasBioentityTypes - retrieve just the non-bioentity type properties (e.g. for $atlasBioentityType = 'ensgene',
          # the gene identifier is the first column in the file - there's no point including that same gene identifier as a property in asubsequent column 
          if [[ $atlasBioentityType != *${atlasProperty}* ]]; then 
	     ensemblProperties=`grep "^property.${atlasProperty}=" ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr "," " "`
	     outFile="${outputDir}/${organism}.${atlasBioentityType}.${atlasProperty}.tsv"
	     rm -f $outFile
             for ensemblProperty in $ensemblProperties; do
                echo "[INFO] Fetching $organism :: $atlasBioentityType : $ensemblBioentityType : $atlasProperty : $ensemblProperty"
		fetchProperties $url $serverVirtualSchema $datasetName $ensemblBioentityType $ensemblProperty $chromosomeName >> $outFile
             done
          fi
       done

       # If $atlasBioentityType = gene, also retrieve synonyms (via mysql) as the last column
       if [[ "$atlasBioentityType" == "ensgene" ]]; then 
	   atlasProperty="synonym"
           echo "[INFO] Fetching $organism :: $atlasBioentityType : $ensemblBioentityType : synonym"
	   fetchGeneSynonyms $organism $mySqlDbHost $mySqlDbPort $mySqlDbName $softwareVersion > ${outputDir}/${organism}.${atlasBioentityType}.${atlasProperty}.tsv
       fi       
    done

    # Retrieve all array desings - for genes only - each array design into a separate file
    for atlasArrayDesign in `grep "^arrayDesign\." ${annSrcsDir}/$organism | awk -F"=" '{print $1}' | awk -F"." '{print $2}'`; do
       ensemblArrayDesign=`grep "^arrayDesign.${atlasArrayDesign}=" ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
       # We retrieve array design mappings for genes only
       atlasBioentityType="ensgene"
       ensemblBioentityType=`grep "^property.${atlasBioentityType}=" ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
       echo "[INFO] Fetching $organism :: $atlasBioentityType : $ensemblBioentityType : $ensemblArrayDesign : $atlasArrayDesign"
       echo -e "$atlasBioentityType\tdesign_element" > ${outputDir}/${organism}.${atlasArrayDesign}.tsv 
       # Note removing of lines with trailing tab (i.e. with bioentity and no corresponding design element)
       fetchProperties $url $serverVirtualSchema $datasetName $ensemblBioentityType $ensemblArrayDesign $chromosomeName | sed '/\t$/d' >> ${outputDir}/${organism}.${atlasArrayDesign}.tsv
    done
done
# Remove auxiliary Ensembl registry files
rm -rf ~/tmp/*.registry.$$

