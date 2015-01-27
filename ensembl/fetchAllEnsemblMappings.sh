#!/bin/bash
# This script retrieves all properties for each bioentity type for each annotation source config file defined in ${annSrcsDir}/ 
# Author: rpetry@ebi.ac.uk

source ${ATLAS_PROD}/sw/atlasprod/bash_util/generic_routines.sh

# Get directory containing annotation source files and the output directory for bioentity property output files
annSrcsDir=$1
outputDir=$2
# The organism argument is optional - can be used for importing just one organism's annotations, e.g. when we add a new array design and don't
# want to go through the whole 
selectedOrganism=$3 
if [[ -z "$annSrcsDir" || -z "$outputDir" ]]; then
    echo "Usage: annSrcsDir outputDir" >&2
    exit 1
fi

for organism in $(ls ${annSrcsDir}/); do
    # Get all the necessary data for retrieval of mappings from the annotation source config file: 
    # ${annSrcsDir}/$organism and the associated registry settings
    # Process only $selectedOrganism if it was specified
    if [ ! -z "$selectedOrganism" ]; then 
	if [ "$organism" != "$selectedOrganism" ]; then
	    continue
	fi
    fi
    url=`grep '^url=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr -d "?"`
    datasetName=`grep '^datasetName=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    softwareName=`grep '^software.name=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    softwareVersion=`grep '^software.version=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    mySqlDbName=`grep '^mySqlDbName=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    mySqlDbUrl=`grep '^mySqlDbUrl=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
    mySqlDbHost=`echo $mySqlDbUrl | awk -F":" '{print $1}'`
    mySqlDbPort=`echo $mySqlDbUrl | awk -F":" '{print $2}'`
    atlasBioentityTypes=`grep '^types=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr "," "\n"`
    chromosomeName=`grep '^chromosomeName=' ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`

    registry=~/tmp/${softwareName}.registry.$$
    curl -s -X GET "${url}?type=registry" | grep "database=\"${softwareName}_mart_${softwareVersion}" | tr " " "\n" > $registry
    mart=`grep 'name=' $registry | awk -F"=" '{print $NF}' | tr -d '\"'`
    serverVirtualSchema=`grep 'serverVirtualSchema=' $registry | awk -F"=" '{print $NF}' | tr -d '\"'`
    # Retrieve property values for each Ensembl bioentity in turn
    for atlasBioentityType in $atlasBioentityTypes; do

       ensemblBioentityType=`grep "^property.${atlasBioentityType}=" ${annSrcsDir}/$organism | awk -F"=" '{print $NF}'`
       # Iterate through all properties and retrieve values for each in turn (exclude bioentity type properties)
       for atlasProperty in `grep "^property\." ${annSrcsDir}/$organism | awk -F"=" '{print $1}' | awk -F"." '{print $2}'`; do       
          # Omit each property in $atlasBioentityTypes - retrieve just the non-bioentity type properties (e.g. for $atlasBioentityType = 'ensgene',
          # the gene identifier is the first column in the file - there's no point including that same gene identifier as a property in the subsequent column 
          if [[ $atlasBioentityType != *${atlasProperty}* ]]; then 
	     ensemblProperties=`grep "^property.${atlasProperty}=" ${annSrcsDir}/$organism | awk -F"=" '{print $NF}' | tr "," "\n"`
	     outFile="${outputDir}/${organism}.${atlasBioentityType}.${atlasProperty}.tsv"
	     rm -f $outFile
             for ensemblProperty in $ensemblProperties; do
                echo "[INFO] Fetching $organism :: $atlasBioentityType : $ensemblBioentityType : $atlasProperty : $ensemblProperty"
		fetchProperties $url $serverVirtualSchema $datasetName $ensemblBioentityType $ensemblProperty $chromosomeName >> $outFile
             done
	     # Some files may contain empty lines (e.g. homo_sapiens.ensgene.disease.tsv) - these empty lines need to be removed, otherwise the merged
	     # file - the output  of mergePropertiesIntoMatrix.pl - will contain empty lines too - which could be a problem for gene properties Solr index 
	     # building that consumes it.
	     grep -v '^$' $outFile > $outFile.tmp
	     mv $outFile.tmp $outFile
	     # This is for human disease property - the file in Ensembl 78 seems to contain lots of rows that don't start with gene identifier (this didn't happen
	     # in Ensembl 77). This may be a bug on their side, but whatever it is, we keep only rows with gene identifiers in the first column.
	     if [ "$organism" == "homo_sapiens" ]; then
		 if [ "$atlasProperty" == "disease" ]; then
		    grep '^ENS' $outFile > $outFile.tmp
		    mv $outFile.tmp $outFile
		 fi
	     fi
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

