#!/usr/bin/env perl

=pod

=head1 NAME

GetEnsemblOrthologs.pl - a script to update orthologs sets in Ensembl annotation sources

=head1 SYNOPSIS

GetEnsemblOrthologs.pl -i input directory -o output directory
GetEnsemblOrthologs.pl -i /ebi/microarray/home/satkos/annotation -o /ebi/microarray/home/satkos/NewOrthologs

=head1 DESCRIPTION

Script opens the old files in the annsrcs directory ( /atlasprod/bioentity_annotations/ensembl/annsrcs/) 
or in another user-specified directory,
and looks for datasetName inside the file to be *_gene_ensembl, because all files don't have it.
Selects those ones which have it to be updated. 
Retrieves data from Ensembl, parses it and saves new orthologs into new file and into
user specified directory.
These new files then have to save to the /atlasprod/bioentity_annotations/ensembl/annsrcs/ directory
and push to the master branch of the Git.

=head1 OPTIONS

=over 2

=item -i --inputdir

Required. Specify a directory to read input files. For example full path to this directory
/atlasprod/bioentity_annotations/ensembl/annsrcs/

=item -o --outputdir

Required. Specify a directory (full path) where to put output files.

=item -h --help

print help documentation

=back

=head1 AUTHOR

Satu Koskinen (satkos@ebi.ac.uk), ArrayExpress team, EBI, 2015. 

=cut

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use File::Basename;
use File::Spec;
use Log::Log4perl qw( :easy );
use 5.10.0;

# Initialise logger.
Log::Log4perl->easy_init (
    {
        level   => $INFO,
        layout  => '%-5p - %m%n',
        file    => "STDOUT",
    }
);

my $logger = Log::Log4perl::get_logger;

# Parse command line arguments.
my $args = parse_args();

# Save the given directory to the variable
my $dir = $args->{"input_directory"};
$logger->info( "Reading files from $dir ..." );


my $outDir =  $args->{"output_directory"};
#Warns you if the directory doesn't exist
unless( -d $outDir ) { $logger->logdie( "$outDir does not exist. Please create it and try again." ); }

# Parses the directory and makes array of the file names
# which are used in opening the file
my @FileNames = ();

opendir my $dh, $dir or $logger->logdie("Could not open '$dir' for reading: $!\n");
$logger->info( "Open the annotation files in $dir for reading..." );


# The names will also include . representing the current directory, and .. representing the parent directory.
# skip these ie. don't put them into array
while (my $thing = readdir $dh) {
	if ($thing eq '.' or $thing eq '..') {
        next;
    }
	push (@FileNames, $thing);
}

closedir $dh;

# Make a list of allowed ortholog species. These should be the first letter of
# the genus and the last letter of the species.
my %orthologSpecies;
foreach my $annsrcFile ( @FileNames ) {

    my @splitSpecies = split "_", basename( $annsrcFile );

    my $firstLetter = substr( $splitSpecies[ 0 ], 0, 1 );

    my $newSpecies = $firstLetter . $splitSpecies[ 1 ];

    $orthologSpecies{ $newSpecies } = 1;
}

# Parses file names and opens the file, and then reads it.
foreach my $name (@FileNames){

	my $fileName = File::Spec -> catfile($dir, $name);
	
	#reading file
	open (my $fh , '<' , $fileName) or die "Can't open $fileName, $!\n";
	
	# Saves ortholog gene names to the array
	my @orthologs = ();
	
	my $orgName = "empty";
		
	# looks for datasetName inside the file to be *_gene_ensembl
	while (my $line = <$fh>) {
    	chomp $line;
    	
    	if ($line =~ /^datasetName/) {
    		my $dsName = $line;
    		#saves the last part of the line after '='
			$dsName =~ s/.*=(\w+)$/$1/; 
			
			# Replases organism name in the url
			if ($dsName =~ /_gene_ensembl$/) {
 				my $address = "http://www.ensembl.org/biomart/martservice?dataset=" . $dsName . "&mart=ENSEMBL_MART_ENSEMBL&type=attributes";
				$orgName = $name; # saves name of the file which needs updating
				$logger->info( "Processing $orgName ..." );
				
				# calls the subroutine, which downloads the content of the web page
				my $result = retrieve_text_over_http($address);

				#splits the downloaded text by the newline and then every line by tab 
				my @ensemblLine = split('\n',$result);
				
				foreach my $line (@ensemblLine) {
					my @splitLine = split('\t',$line);
					
					#Tests if the first element of the line has '_homolog_ensembl_gene$'
					# if so pushes the element onto orthologs array
					if ($splitLine[0] =~ /_homolog_ensembl_gene$/){

                        my @splitOrthAttribute = split "_", $splitLine[ 0 ];

                        my $orthSpecies = $splitOrthAttribute[ 0 ];

                        if( $orthologSpecies{ $orthSpecies } ) {

                            push (@orthologs, $splitLine[0]);
                        }
                        else {
                            say "Skipping non-Atlas species $orthSpecies.";
                        }
					}
								
				}
			last;	# breaks out of the loop, because datasetName is found.
			}
    	}
	}
 	close $fh;
 	#separates orthologs with comma in the list
 	my $orthologNames = join (',', @orthologs);
 	
 	#  Opens the files and rewrites them with the new information if found
 	my $i = File::Spec -> catfile($dir, $name);
	open (my $fileh , '<' , $i) or die "Can't open $i, $!\n";
	
	# only the files, that need to be updated, are saved to NewOrthologs directory 
	if ($orgName eq $name) {
		my $j = File::Spec -> catfile($outDir, $name);
		$logger->info( "Writing new annotation source for $name to: $j" );
		open (my $fh_new, '>' , $j) or die "Can't open $j, $!\n";
	

	
	# Looks for the property.ortholog line
	while (my $line = <$fileh>) {
    	chomp $line;
    	if ($line =~ /^property.ortholog/) {
    		say $fh_new "property.ortholog=$orthologNames";
    	}
    	else {
    		say $fh_new $line;
    	}
	}
	close $fh_new;
	close $fileh;
	}
}

$logger->info( "All the orthologs updated, work completed" );


### SUBROUTINES ###

# subroutine to download the content of the web page
sub retrieve_text_over_http {

    my ( $url ) = @_;

    # User agent to execute the query.
    my $userAgent = LWP::UserAgent->new;

    # Use the proxy from the current user's environment, if any.
    $userAgent->env_proxy;

    # Initialise an HTTP get request with the query URL.
    my $request = HTTP::Request->new(
        GET => $url
    );

    # We expect text content. Don't allow anything else.
    $request->header( 'Accept' => 'text/plain' );

    $logger->info( "Querying for content from: $url ..." );

    my $response = $userAgent->request( $request );

    # Check if the request was successful.
    my $numRetries = 0;
    while( $numRetries < 3 && ! $response->is_success ) {
        
        $logger->warn( "Query unsuccessful: ", $response->status_line , ", retrying..." );
        
        $response = $userAgent->request( $request );
        $numRetries++;
    }

    unless( $response->is_success ) {
        $logger->error( 
            "Maximum number of retries reached. Service appears to be unresponsive (", 
            $response->status_line,
            ")."
        );

        return;
    }
    else {
        $logger->info( "Query successful." );
    }
    
    # Warn if content is empty.
    if( ! $response->decoded_content ) {
        $logger->warn( "No content found for URL $url" );
    }

    # Return the text.
    return $response->decoded_content;
}


# subroutine parse_args
# 	- Read arguments from command line.
sub parse_args {
	# Add the arguments to this hash with relevant options.
	my %args;
	# Set this if -h passed.
	my $want_help;
	

	GetOptions(
		"h|help"			=> \$want_help,
		"i|inputdir=s"		=> \$args{ "input_directory" },	# dir for file
		"o|outputdir=s"		=> \$args{ "output_directory" }
		#"d|debug"			=> \$args{ "debug" },
	);

	if($want_help) {
		pod2usage(
			-exitval => 255,
			-output => \*STDOUT,
			-verbose => 1
		);
	}

	# We must have input directory and type in order to do anything.
	unless($args{ "input_directory" }) { 
		pod2usage(
			-message => "You must specify an input directory for the files, that need to be updated.\n",
			-exitval => 255,
			-output => \*STDOUT,
			-verbose => 1,
		);
	}
	
	# We must have output directory and type in order to do anything.
	unless($args{ "output_directory" }) { 
		pod2usage(
			-message => "You must specify an output directory for the files.\n",
			-exitval => 255,
			-output => \*STDOUT,
			-verbose => 1,
		);
	}
	return \%args;
}
