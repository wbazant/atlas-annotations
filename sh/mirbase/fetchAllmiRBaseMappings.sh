#!/bin/bash
# This script retrieves all miRBase mature miRNA and stem-loop sequence properties
# Author: rpetry@ebi.ac.uk

outputDir=$1
if [[ -z "$outputDir" ]]; then
    echo "Usage: $0 outputDir"  >&2
    exit 1
fi

# Fetch the latest mature.fa, hairpin.fa and miRNA.dat files from miRBase
rm -rf ${outputDir}/mature.fa
rm -rf ${outputDir}/hairpin.fa
rm -rf ${outputDir}/miRNA.dat
curl -X GET -s -o ${outputDir}/mature.fa.gz "ftp://mirbase.org/pub/mirbase/CURRENT/mature.fa.gz" && gunzip ${outputDir}/mature.fa.gz
curl -X GET -s -o ${outputDir}/hairpin.fa.gz "ftp://mirbase.org/pub/mirbase/CURRENT/hairpin.fa.gz" && gunzip ${outputDir}/hairpin.fa.gz
curl -X GET -s -o ${outputDir}/miRNA.dat.gz "ftp://mirbase.org/pub/mirbase/CURRENT/miRNA.dat.gz" && gunzip ${outputDir}/miRNA.dat.gz

# Bring sequence in line with the rest of the information in mature.fa and hairpin.fa
perl -pi -e 's|\n| |g' ${outputDir}/mature.fa
perl -pi -e 's|\>|\n>|g' ${outputDir}/mature.fa

perl -pi -e 's|stem-loop\n||g' ${outputDir}/hairpin.fa
perl -pi -e 's|stem\sloop\n||g' ${outputDir}/hairpin.fa
perl -pi -e 's|\n||g' ${outputDir}/hairpin.fa
perl -pi -e 's|\>|\n>|g' ${outputDir}/hairpin.fa

IFS="
"

# Obtain mapping between hairpin and mature miRNAs 
# Example relevant lines in miRNA.dat:
# ID   hsa-mir-33b       standard; RNA; HSA; 96 BP.
# AC   MI0003646;
# FT                   /accession="MIMAT0003301"
# FT                   /product="hsa-miR-33b-5p"
# FT                   /accession="MIMAT0004811"
# FT                   /product="hsa-miR-33b-3p"

# Obtain mapping between hairpin and mature miRNAs
echo -e "hairpinSymbol\thairpinIdentifier\tmatureSymbol\tmatureIdentifier" > ${outputDir}/hairpin_to_mature.txt
for l in $(grep -P '^ID|^AC|\/accession="|\/product="' ${outputDir}/miRNA.dat); do
    if [[ $l == ID* ]]; then
	hairpinSymbol=`echo $l | awk '{print $2}'`
    elif [[ $l == AC* ]]; then	
	hairpinIdentifier=`echo $l | awk '{print $2}' | sed '$s/;$//'`
    elif [[ $l == FT*/accession=* ]]; then	
	matureIdentifier=`echo $l | awk -F"=" '{print $2}' | sed '$s/"$//' |  sed '$s/^"//'`
    elif [[ $l == FT*/product=* ]]; then	
	matureSymbol=`echo $l | awk -F"=" '{print $2}' | sed '$s/"$//' |  sed '$s/^"//'`
	if [ -z "$hairpinSymbol" -o -z "$hairpinIdentifier" -o -z "$matureSymbol" -o -z "$matureIdentifier" ]; then
	    echo "ERROR: One of the values is missing in : "$hairpinSymbol\t$hairpinIdentifier\t$matureSymbol\t$matureIdentifier"" >&2
	    exit 1
        fi
	echo -e "$hairpinSymbol\t$hairpinIdentifier\t$matureSymbol\t$matureIdentifier" >> ${outputDir}/hairpin_to_mature.txt
    fi
done

# Obtain properties of mature and hairpin miRNAs
for f in mature; do
   # Get individual values from each line
   for l in $(cat ${outputDir}/${f}.fa); do
       mirbaseSymbol=`echo $l | awk '{print $1}' | awk -F">" '{print $NF}'`
       mirbase_id=`echo $l | awk '{print $2}'`
       if [ $f == "mature" ]; then
	   # Longer organisms are truncated, for example for hvt-miR-H14-5p, organism 'Herpesvirus of turkeys' 
	   # becomes 'Herpesvirus of' in mature.fa. Hence, for mature miRNA, we need to get organism from hairpin.fa
	   # via the hairpin id corresponding to $mirbase_id in ${outputDir}/hairpin_to_mature.txt
	   # Note: head -1 below to just catch the first matching hairpin - as there can be more for a given mature mirbase_id
	   # TODO: handle multiple hairpin_ids for a single mature miRNA correctly - the current logic ignores all but the first corresponding hairpin
	   hairpinIdentifier=`grep "$mirbase_id$" ${outputDir}/hairpin_to_mature.txt | head -1 | awk -F"\t" '{print $2}'`
	   if [[ -z "$hairpinIdentifier" ]]; then
		  echo "ERROR: Unable to retrieve hairpinIdentifier for mature miRNA: $mirbase_id" >&2
	          exit 1
	   fi 
	   # Note the removal of any dots at the end of the species name - as this breaks that file parsing later (e.g. 'Saccharum ssp.')
	   organism=`grep " ${hairpinIdentifier} " ${outputDir}/hairpin.fa | awk '{for (i = 3; i <= NF-2; i++) printf $i " "; print ""}' | sed 's/ *$//g' | sed 's/\.*$//g'`
       else
           organism=`echo $l | awk '{for (i = 3; i <= NF-2; i++) printf $i " "; print ""}' | sed 's/ *$//g' | sed 's/\.*$//g'`
       fi
       # Lower-case organism and replace spaces with underscores - organism will be used in mirRNA property file names
       organism=`echo $organism | tr '[A-Z]' '[a-z]'`
       organism=`echo $organism | tr ' ' '_'`
       if [ ! -e  ${outputDir}/${organism}.${f}.tsv ]; then
	   if [ $f == "mature" ]; then
	       # For mature sequences we also store the identifier of their parent hairpin (stem-loop)
	       echo -e "mirna\tmirbase_accession\tsymbol\tmirbase_name\tmirbase_sequence\thairpin_id\tgene_biotype" > ${outputDir}/${organism}.${f}.tsv
	   else 
	       echo -e "mirna\tmirbase_accession\tsymbol\tmirbase_name\tmirbase_sequence\tgene_biotype" > ${outputDir}/${organism}.${f}.tsv
	   fi
       fi 
       mirbase_name=`echo $l | awk '{print $(NF-1)}'`
       mirbase_sequence=`echo $l | awk '{print $NF}'`
       if [ $f == "mature" ]; then
	      echo -e "$mirbase_id\t$mirbase_id\t$mirbaseSymbol\t$mirbase_name\t$mirbase_sequence\t$hairpinIdentifier\tmiRNA" >> ${outputDir}/${organism}.${f}.tsv
       else 
	      echo -e "$mirbase_id\t$mirbase_id\t$mirbaseSymbol\t$mirbase_name\t$mirbase_sequence\tmiRNA" >> ${outputDir}/${organism}.${f}.tsv
       fi
   done
done

# Store in idprefix_to_organism.tsv a mapping between each unique prefix in miRBase identifiers and its corresponding organism
# This file will be used to split miRNA array design mapping files into species-specific portions - so that they can be loaded into Solr index
# Note that mature files are not used - this is to do with species names not being correctly stored in mature.fa, e.g. compare
# mature.fa: >hvt-miR-H14-5p MIMAT0012866 Herpesvirus of miR-H14-5p UCAUUCAGCGGGCAAUGUAGACUGU 
# with
# hairpin.fa: >hvt-mir-H14 MI0012627 Herpesvirus of turkeys miR-H14 CGGACUCAUUCAGCGGGCAAUGUAGACUGUGUACCAAGUGACAGCUACAUUGCCCGCUGGGUUUCUG
pushd ${outputDir}
for f in $(ls *.hairpin.tsv); do 
    organism=`echo $f | awk -F"." '{print $1}'`
    idprefix=`tail -1 $f| awk -F"-" '{print $1}'`
    echo -e "$idprefix\t$organism" 
done | sort | uniq > idprefix_to_organism.tsv
popd

exit 0



