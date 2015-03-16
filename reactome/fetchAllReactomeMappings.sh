#!/bin/bash
# This script retrieves Ensembl gene identifier - Reactome pathway identifier - Reactome pathway name triples and puts them in ${organism}.reactome.tsv files, depending on the organism of the Ensembl gene identifier
# Author: rpetry@ebi.ac.uk

outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir" >&2
    exit 1
fi

pushd $outputDir
IFS="
"

# Clean up previous files
rm -rf $outputDir/*.reactome.tsv*
rm -rf $outputDir/aux*

start=`date +%s`
# Retrieved columns are in order: ensembl gene identifier/Uniprot accession, organism, Reactome pathway accession, Reactome Pathway name
for file in Ensembl2Reactome UniProt2Reactome UniProt2PlantReactome; do
    if [ "$file" == "UniProt2PlantReactome" ]; then
	# Please note that UniProt2PlantReactome.txt is currently provided manually by Justin Preece from Gramene project
	cat ${file}_All_Levels.txt | awk -F"\t" '{print $1"\t"$6"\t"$2"\t"$4}' | sort -k 1,1 > aux.$file
    else 
	curl -s -X GET "http://www.reactome.org/download/current/${file}_All_Levels.txt" | awk -F"\t" '{print $1"\t"$6"\t"$2"\t"$4}' | sort -k 1,1 > aux.$file
    fi
    # Ensembl2Reactome appears to map to pathways a combination of gene and transcript identifiers (I've seen evidence of a gene and its transcript
    # being mapped to the same pathway in separate lines of the same file). Exluding transcript identifers to avoid Solr index (that consumes these files)
    # from being corrupted.
    if [ "$file" == "Ensembl2Reactome" ]; then 
	grep -vP '^ENST' aux.$file > aux.$file.tmp
	mv aux.$file.tmp aux.$file
    fi

    # Lower-case and replace space with underscore in all organism names; create files with headers for each organism
    awk -F"\t" '{print $2}' aux.$file | sort | uniq > aux.$file.organisms
    for organism in $(cat aux.$file.organisms); do
       lcOrganism=`echo $organism | tr '[A-Z]' '[a-z]' | tr ' ' '_'`
       perl -pi -e "s|$organism|$lcOrganism|g" aux.$file
    done

    # Append data retrieved from REACTOME into each of the species-specific files 
    # (each file contains the portion of the original data for the species in that file's name)
    if [ "$file" == "Ensembl2Reactome" ]; then 
	awk -F"\t" '{print $1"\t"$3"\t"$4>>$2".reactome.tsv"}' aux.$file
    else
	# For UniProt file we first need to map UniProt accessions to Ensembl identifiers,
	# before appending the data to ${lcOrganism}.reactome.tsv
	for organism in $(cat aux.$file.organisms); do
	    lcOrganism=`echo $organism | tr '[A-Z]' '[a-z]' | tr ' ' '_'`	
	    # First prepare the ${lcOrganism} portion of Uniprot2Reactome
	    grep -P "\t$lcOrganism\t" aux.$file | awk -F"\t" '{print $1"\t"$3"\t"$4}' | sort -k1,1 | uniq > aux.${lcOrganism}.reactome.tsv
	    uniprotMapingFile=$ATLAS_PROD/bioentity_properties/ensembl/${lcOrganism}.ensgene.uniprot.tsv
	    ls $uniprotMapingFile > /dev/null 2>&1
	    if [ -s $uniprotMapingFile ]; then
	       # Now prepare Ensembl's UniProt to Ensembl mapping file - in the right order, ready for joining with the $lcOrganism portion of Ensembl2Reactome
	       grep -vP '\t$' $uniprotMapingFile | awk -F"\t" '{print $2"\t"$1}' | sort -k1,1 | uniq > aux.${lcOrganism}.ensembl.tsv
	       if [ -s aux.${lcOrganism}.ensembl.tsv ]; then 
	           # Join to Ensmebl mapping file, then remove protein accessions before appending the UniProt only-annotated pathways to ${lcOrganism}.reactome.tsv
		   join -t $'\t' -1 1 -2 1 aux.${lcOrganism}.ensembl.tsv aux.${lcOrganism}.reactome.tsv | awk -F"\t" '{print $2"\t"$3"\t"$4}' >> ${lcOrganism}.reactome.tsv
		   # Finally, remove any duplicate rows
		   echo -e "ensgene\tpathwayid\tpathwayname" > ${lcOrganism}.reactome.tsv.tmp
		   sort  -k1,1 -t$'\t' ${lcOrganism}.reactome.tsv | uniq >> ${lcOrganism}.reactome.tsv.tmp
		   mv ${lcOrganism}.reactome.tsv.tmp ${lcOrganism}.reactome.tsv
	       fi
	    fi 
	done
    fi
done

# Prepare head-less ensgene to pathway name mapping files for the downstream GSEA analysis
cat aux.Ensembl2Reactome > aux
cat aux.UniProt2Reactome >> aux
cat aux.UniProt2PlantReactome >> aux
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

rm -rf aux*
end=`date +%s`
echo "Operation took: "`expr $end - $start`" s"

popd




