#!/usr/bin/env perl

#POD documentation - main docs before the code
=pod

=head1 NAME

  Karyn Megy - 22-July-13
  kmegy@ebi.ac.uk
  mergePropertiesIntoMatrix.pl

=head1 SYNOPSIS

 From a given list of annotation file (<species>.<bioentity>.<property>.tsv) 
  generate a single file containing all the data. 

=head1 DESCRIPTION

   For a given species & bioentity, from a list of annotation files (<species>.<bioentity>.<property>.tsv)
   generate a single file containing all the property and their values for that species & bioentity. 

  The files to merge are of type:
    ENSG000123	value1
    ENSG000123	value2
    ENSG000456	value2
    ENSG000789	value3 
	etc. 

  The file name provide information on the species (e.g. homo_sapiens), 
  the bioentity (e.g. gene) and the property we have the values for (e.g. uniprot)

  There are some assumption on the input directory:
     - it contains only files with bioentity annotations (for a given property, for a given bioentity and for a given organism)
     - file names are expected to be <species>.<bioentity>.<property>.tsv


=head1 OPTIONS

  none

=head1 EXAMPLES

  mergePropertiesIntoMatrix.pl -indir <directory_with_files_to_merge> -species <species> -bioentity <bioentity type> -outdir <output directory>

  E.g. 
  mergePropertiesIntoMatrix.pl -indir $ATLAS_PROD/bioentity_properties/ensembl/ -bioentity gene -species homo_sapiens -outdir ./

=cut


use strict ;
use warnings ;
no warnings 'uninitialized';
use Getopt::Long qw(:config no_ignore_case);
use File::Spec;

## Initialise global $, @ and %
my ($help, $indir, $outdir, $species, $bioentity) ; #arguments

#Hash storing data for all the files
#  %H_dataMatrix{bioentity}{property}{value} = 1
#E.g.
#  $H_dataMatrix{ENSG-1}{UniProt}{Q9BLD0} = 1
#  $H_dataMatrix{ENSG-1}{UniProt}{Q2DMX2} = 1
#  $H_dataMatrix{ENSG-2}{UniProt}{P11055} = 1
#  etc. 
my (%H_dataMatrix, $Href_dataMatrix) ;

#Ordered list of all the properties
#Required for final printing	
my @A_propertyList ;


## Get arguments
################
GetOptions( 
    'help|Help|h|H' => \$help,
	'indir=s'   => \$indir,
    'species=s' => \$species,
	'bioentity=s' => \$bioentity,
    'outdir=s'  => \$outdir,
);

my $commandLine = join(' ',@ARGV); 

#Test arguments
if (!$indir || !$outdir) { print "[WARNING] Missing input (-indir) or output (-outdir) directories\n" ; $help  = 1 ; }
if (!$bioentity || !$species) { print "[WARNING] Missing species (-species) or bioentity (-bioentity)\n" ; $help  = 1 ; }
if ($help) { usage($commandLine); die; }

#Output file
my $outfile = "$species.$bioentity.tsv";   

## Main program
###############
## 1. Collect the files names, 
##    Store in an array

#List files in the $indir directory which are like: $species.$bioentity.*.tsv
opendir (DIR, $indir);
my @A_fileList = grep { (/$species\.$bioentity\..+?\.t/)} readdir(DIR);
closedir DIR ;

#Die if no file returned
if (scalar @A_fileList == 0) { die "[WARNING] Could not retrieve any files in $indir for species $species and bioentity $bioentity.\n" ; }

#Print & die - for checking
#for my $file (@A_fileList) { print ">> $file\n" ; } exit ;

# 2. Parse the file array: 
##     - For each file, extract the data
##     - Store in a hash - same hash for all file / data type!
##       (%H_matrix{bioentity}{property}{value} = 1)
##     - And store the property name in an array
##       (retrieve them in order when printing)
for my $file (@A_fileList) {
	print STDERR "Parsing $file\n" ;	
		
	# Get the property 
	# File name should be: <species>.<bioentity>.<property>.tsv
	my $property ;
	if ($file =~ /\w+?\.\w+?\.(\w+?).tsv/) { $property = $1 ; }
	else { die "[WARNING] Could not capture property in file name $file!\n" ; }

	#Store the property list in an array
	#So that I can retrive them in the same order later
	push(@A_propertyList, $property) ; #add to the end of the array (unshift for beginning)

	#Parse the file and store data in a hash
	#!! We are adding to the same hash every time because we want everything ina single hash !! 
	$Href_dataMatrix = &parseTSVfile("$indir/$file", $property) ;	
	%H_dataMatrix = %$Href_dataMatrix ; #dereference (clearer later)
}


## 3. Print the matrix
open (FOUT, ">:encoding(UTF-8)", File::Spec->catfile( $outdir, $outfile ) ) || die ("Can't open output file $outfile\n") ;

## Print the header
print FOUT "$bioentity\t" ;
my $title = join "\t", @A_propertyList;
print FOUT $title ;
print FOUT "\n" ;

## Print the data
#	bioentity	property-A 	property-B	property-C ...
# 	ENSG000123 	value1 		value2   	value4 ...
#	ENSG000456 	value5@@value5 	 		value8 ...
#	....	
# If several values / property: separate them by @@	value-1@@value-2
# If no value for a given property: blank (NOT space!)
#
foreach my $bioentityID (keys %H_dataMatrix) {
	print FOUT "$bioentityID\t" ;
	for my $property (@A_propertyList) {

		#Write a string (valueString) of all values for that property
		#Values at @@ separated
		#For a given entity & property, there might be a mix of string and BLANK values
		#...clean up the extra @@ afterwards
		my $valueString ;
		foreach my $val (keys %{$H_dataMatrix{$bioentityID}{$property}}) { $valueString .= $val."@@" ; } 
		
		#If defined valueString, remove starting and trailing @@
		#	and replace any >2@  by 2@
		#	e.g. GO:0005634@@@@GO:0006355 -> GO:0005634@@GO:0006355
		#Else, print nothing
		if ($valueString ne "") {
                        $valueString =~ s/\@{3,}/\@\@/ ; #multiple in a row@@
			$valueString =~ s/^\@{2}// ;	#starting
			$valueString =~ s/\@{2}$// ;	#trailing
		} else {
			$valueString = "" ; 
		}		

		#Unless last property, add a tab
		if ($property ne $A_propertyList[-1]) { $valueString .= "\t" ; }

		#Print valueString           
		print FOUT $valueString ;

	} print FOUT "\n" ;		
}
close FOUT ;


## Subroutine
##############
#Print usage for the program
sub usage {
	my $command_line = @_ ;

   	print "Your command line was:\t".
	    "$0 $command_line\n".
	    "Compulsory parameters:\n".
	    "\t-indir: directory containing the input files\n".
	    "\t-outdir: target directory for the output files\n".
            "\t-species: organism\n".
            "\t-bioentity: bioentity type (gene, transcript, protein)\n" ;
}

sub parseTSVfile {
	my $file = $_[0] ;  #file (inc. path) to parse
	my $prop = $_[1] ;  #property (e.g. uniprot) 

        open (F, "$file") || die ("Can't open file $file\n") ;
        while (my $line=<F>) {

                chomp $line ; #remove final /n

                ## Assuming a line is composed of: bioentity identifier TAB value 
                # ENSG-1 val1
                # ENSG-1 val2
                # ENSG-2 val3
                my ($entityID, $value) = split ("\t", $line) ;
                
                #Store the data
                #Populate the existing hash as we want a single data structure
                $H_dataMatrix{$entityID}{$prop}{$value} = 1
	}
	close F ; 
	return \%H_dataMatrix ; #return the hash reference
}                
