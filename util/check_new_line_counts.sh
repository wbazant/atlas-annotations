

if [ $# -lt 2 ] ; then
	echo >&2 "Usage: $0 <previous archive> <current archive>"
	exit 1
fi

previousArchive=$1
currentArchive=$2

fileSizes() {
	for file in $( find $1 -type f) ; do
		echo -n $(basename $file) ; stat $file --printf=" %s\n";
 	done
}

join -1 1 -2 1 <(fileSizes $1 | sort ) <(fileSizes $2 | sort )

#TODO make some kind of calculation on the two lists, and fail if annotations differ in sizes
#TODO also print out annotations present in one but not other?

# Old:
#TODO I used to live in ensemblUpdate.sh and I am a good idea. Make me useful again if you need to!
#--------------------------------------------------
# # Compare the line counts of the new files against those in the previous
# # versions downloaded.
# echo "Checking all mapping files against archive ..."
#
# # Create the path to the directory containing the mapping files we just archived above.
# previousArchive=${ATLAS_PROD}/bioentity_properties/archive/ensembl_${OLD_ENSEMBL_REL}_${OLD_ENSEMBLGENOMES_REL}
#
# # Go through the newly downloaded mapping files.
# for mappingFile in $( ls *.tsv ); do
#
#     # Count the number of lines in the new file.
#     newFileNumLines=`cat $mappingFile | wc -l`
#
#     # Cound the number of lines in the archived version of the same file.
#     if [ -s ${previousArchive}/$mappingFile ]; then
#         oldFileNumLines=`cat ${previousArchive}/$mappingFile | wc -l`
#
#         # Warn to STDOUT and STDERR if the number of lines in the new file is
#         # significantly lower than the number of lines in the old file.
#         if [ $newFileNumLines -lt $oldFileNumLines ]; then
#
#             # Calculate the difference between the numbers of lines.
#             difference=`expr $oldFileNumLines - $newFileNumLines`
#
#             # Only warn if the difference is greater than 2000 genes.
#             # tee is used to send the message to STDOUT as well.
#             if [ $difference -gt 2000 ]; then
#                 echo "WARNING - new version of $mappingFile has $newFileNumLines lines, old version has $oldFileNumLines lines!" | tee /dev/stderr
#             fi
#         fi
#     fi
# done
#
# echo "Finished checking mapping files against archive."
#--------------------------------------------------
