#!/bin/bash
# This script retrieves Ensembl gene identifier - Reactome pathway identifier - Reactome pathway name triples and puts them in ${organism}.reactome.tsv files, depending on the organism of the Ensembl gene identifier
# Author: rpetry@ebi.ac.uk
# Note the script uses GNU's extended awk

outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
    exit 1
fi

# I got copypasted from atlasprod's generic_routines because I am very useful here
function find_properties_file() {
  organism=$1
  property=$2
  cat \
    <(find -L ${ATLAS_PROD}/bioentity_properties/wbps -name ${1}.wbpsgene.${2}.tsv) \
    <(find -L ${ATLAS_PROD}/bioentity_properties/ensembl -name ${1}.ensgene.${2}.tsv) \
    | head -n1
}

## function to map uniprot_ds to ensembl_ids
map_uniprot_ids(){
	organism_file=$1
    for organism in $(cat $organism_file); do
    	lcOrganism=`echo $organism | tr '[A-Z]' '[a-z]' | tr ' ' '_'`
    	# First prepare the ${lcOrganism} portion of file
    	grep "\b$lcOrganism\b" aux.$file | awk -F"\t" '{print $1"\t"$3"\t"$4}' | sort -k1,1 | uniq > aux.${lcOrganism}.$file.tsv.tmp
    	uniprotMappingFile=$(find_properties_file $lcOrganism "uniprot")
    	if [ -e "$uniprotMappingFile" ]; then
      		# Now prepare Ensembl's UniProt to Ensembl mapping file - in the right order, ready for joining with the $lcOrganism portion of Ensembl2PlantReactome
      		grep -E '^\w+\W\w+$' $uniprotMappingFile | awk -F"\t" '{print $2"\t"$1}' | sort -u -k1,1 > aux.${lcOrganism}.ensembl.tsv.tmp
      		# Join to Ensmebl mapping file, then remove protein accessions before appending the UniProt only-annotated pathways to ${lcOrganism}.reactome.tsv
      		join -t $'\t' -1 1 -2 1 aux.${lcOrganism}.ensembl.tsv.tmp aux.${lcOrganism}.$file.tsv.tmp | awk -F"\t" '{print $2"\t"$3"\t"$4}' >> ${lcOrganism}.reactome.tsv.tmp
    	fi
  	done
}

IFS="
"

# Clean up previous files
# TODO: let's not - since we also use symlinks to
# rm -rf $outputDir/*.reactome.tsv*
# rm -rf $outputDir/aux*

start=`date +%s`
# Please note that the two files are currently provided manually by Justin Preece from Gramene project
# we check them in and keep them with source code
curl -s -X GET "http://plantreactome.gramene.org/download/current/UniProt2PlantReactome_All_Levels.txt" | awk -F"\t" '{print $1"\t"$6"\t"$2"\t"$4}' | sort -k 1,1 > $outputDir/aux.UniProt2PlantReactome
curl -s -X GET "http://plantreactome.gramene.org/download/current/Ensembl2PlantReactome_All_Levels.txt" | awk -F"\t" '{print $1"\t"$6"\t"$2"\t"$4}' | grep -Ev '^ENST' | sort -k 1,1 > $outputDir/aux.Ensembl2PlantReactome

#Download the other files
curl -s -X GET "https://reactome.org/download/current/UniProt2Reactome_All_Levels.txt" | awk -F"\t" '{print $1"\t"$6"\t"$2"\t"$4}' | sort -k 1,1 > $outputDir/aux.UniProt2Reactome
# Ensembl2Reactome appears to map to pathways a combination of gene and transcript identifiers (I've seen evidence of a gene and its transcript
# being mapped to the same pathway in separate lines of the same file). Exluding transcript identifers to avoid Solr index (that consumes these files)
# from being corrupted.
curl -s -X GET "https://reactome.org/download/current/Ensembl2Reactome_All_Levels.txt" | awk -F"\t" '{print $1"\t"$6"\t"$2"\t"$4}' | grep -Ev '^ENST' | sort -k 1,1 > $outputDir/aux.Ensembl2Reactome

pushd $outputDir

for file in Ensembl2Reactome UniProt2Reactome UniProt2PlantReactome Ensembl2PlantReactome; do
  # extract organism names in each file
  awk -F"\t" '{print $2}' aux.$file | sort -u > aux.$file.organisms
  # Lower-case and replace space with underscore in all organism names; create files with headers for each organism
  for organism in $(cat aux.$file.organisms); do
     lcOrganism=`echo $organism | tr '[A-Z]' '[a-z]' | tr ' ' '_'`
     perl -pi -e "s|$organism|$lcOrganism|g" aux.$file
  done
done

# common plants organisms existing in Ensembl2Reactome and UniProt2Reactome which needs to removed
comm -12 <(sort -u aux.Ensembl2Reactome.organisms) <(sort -u aux.Ensembl2PlantReactome.organisms) | tr '[A-Z]' '[a-z]' | sed 's/\s/_/g' > aux.PlantSpeciesInReactome
comm -12 <(sort -u aux.UniProt2Reactome.organisms) <(sort -u aux.UniProt2PlantReactome.organisms) | tr '[A-Z]' '[a-z]' | sed 's/\s/_/g' >> aux.PlantSpeciesInReactome

# removing plant species from Reactome files - organism, Reactome pathway accession, Reactome Pathway name from Ensembl2Reactome and UniProt2Reactome
# The rationale is reactome files for plants gets populated using Ensembl2PlantReactome and UniProt2PlantReactome 
# and we dont need plant experiments coming from Reactome as they have been corrupted for plant experiments
for file in Ensembl2Reactome UniProt2Reactome; do
	cat aux.$file.organisms | tr '[A-Z]' '[a-z]' | sed 's/\s/_/g' > aux.$file.organisms.NoPlants
	for organism in $(cat aux.PlantSpeciesInReactome); do
    	sed -i '/'$organism'/d' aux.$file
    	sed -i '/'$organism'/d' aux.$file.organisms.NoPlants
  	done
done  

#columns are meant to be in order: ensembl gene identifier, organism, Reactome pathway accession, Reactome Pathway name
# Append data retrieved from REACTOME into each of the species-specific files
# (each file contains the portion of the original data for the species in that file's name) 
for file in Ensembl2Reactome Ensembl2PlantReactome ;do 	
  	awk -F"\t" '{print $1"\t"$3"\t"$4>>$2".reactome.tsv.tmp"}' aux.$file
done

#columns are meant to be in order: Uniprot accession, organism, Reactome pathway accession, Reactome Pathway name
# For UniProt file we first need to map UniProt accessions to Ensembl identifiers,
# before appending the data to ${lcOrganism}.reactome.tsv.tmp
map_uniprot_ids aux.UniProt2Reactome.organisms.NoPlants
map_uniprot_ids aux.UniProt2PlantReactome.organisms

for outFile in $(ls *reactome.tsv.tmp); do
  resultFile=$(echo $outFile | sed 's/tsv.tmp/tsv/')
  cat <(echo -e "ensgene\tpathwayid\tpathwayname") <(sort -k1,1 -t$'\t' $outFile | uniq) > $resultFile
done

# Prepare head-less ensgene to pathway name mapping files for the downstream GSEA analysis
cat aux.Ensembl2Reactome > aux
cat aux.UniProt2Reactome >> aux
cat aux.UniProt2PlantReactome >> aux
cat aux.Ensembl2PlantReactome >> aux
awk -F"\t" '{print $1"\t"$3>>$2".reactome.tsv.gsea.aux"}' aux
# Remove any duplicate rows
for f in $(ls *.reactome.tsv.gsea.aux); do
    sort  -k1,1 -t$'\t' $f | uniq > $f.tmp
    mv $f.tmp $f
done


# Prepare head-less pathway name to pathway accession mapping files, used to decorate the *.gsea.tsv files produced by the downstream GSEA analysis
awk -F"\t" '{print $3"\t"$4>>$2".reactome.tsv.decorate.aux"}' aux
# Remove any duplicate rows
for f in $(ls *.reactome.tsv.decorate.aux); do
   cat $f | sort -k1,1 -t$'\t' | uniq > $f.tmp
   mv $f.tmp $f
done

rm -rf aux
rm -rf aux.*
rm -rf *tmp
end=`date +%s`
echo "Operation took: "`expr $end - $start`" s"

popd
