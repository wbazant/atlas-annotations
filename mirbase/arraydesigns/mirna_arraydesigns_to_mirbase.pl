#!/usr/bin/env perl
#
=pod

=head1 NAME

mirna_arraydesign_to_mirbase.pl - map array design probe IDs to miRBase accessions

=head1 SYNOPSIS

mirna_arraydesign_to_mirbase.pl -m aliases.txt 

=head1 DESCRIPTION

This script takes a file containing miRBase accessions and their identifier(s),
goes through a list of array design accessions, and for each one tries to map
the probe names from the ADF to miRBase accessions. It writes a file containing
the mappings to the appropriate directory in $ATLAS_PROD/arraydesigns/microRNA .

=head1 OPTIONS

=over 2

=item -m --mirbase-aliases

Required. Path to file containing miRBase accessions and their corresponding identifier(s).

=item -h --help

Print a helpful message.

=back

=head1 AUTHOR

Expression Atlas team <arrayexpress-atlas@ebi.ac.uk>

=cut

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;
use File::Spec;
use Log::Log4perl;
use Log::Log4perl::Level;
use DateTime;
use Math::Round;

use AtlasSiteConfig;
use Bio::MAGETAB::Util::Reader::ADF;

# Auto flush buffer.
$| = 1;

my $args = &parse_args();

# Config for logger.
my $logger_config = q(
	log4perl.category.MIRNA_ARRAY_MAPPING_LOGGER = INFO, LOG1, SCREEN
	log4perl.appender.SCREEN             = Log::Log4perl::Appender::Screen
	log4perl.appender.SCREEN.stderr      = 0
	log4perl.appender.SCREEN.layout      = Log::Log4perl::Layout::PatternLayout
	log4perl.appender.SCREEN.layout.ConversionPattern = %-5p - %m%n
	log4perl.appender.LOG1             = Log::Log4perl::Appender::File
	log4perl.appender.LOG1.filename    = sub { get_log_file_name }
	log4perl.appender.LOG1.header_text = sub { get_log_file_header }
	log4perl.appender.LOG1.mode        = append
	log4perl.appender.LOG1.layout      = Log::Log4perl::Layout::PatternLayout
	log4perl.appender.LOG1.layout.ConversionPattern = %-5p - %m%n
);

# Initialise logger.
Log::Log4perl::init( \$logger_config );
my $logger = Log::Log4perl::get_logger( "MIRNA_ARRAY_MAPPING_LOGGER" );

# Get atlas prod directory (from $ATLAS_PROD environment variable).
my $atlasProdDir = $ENV{ "ATLAS_PROD" } 
	or $logger->logdie( "ATLAS_PROD environment variable not found." );

$logger->info( "Reading miRBase aliases from from ", $args->{ "mirbase_aliases_file" } );
my $mirbaseAliases = &make_mirbase_aliases( $args->{ "mirbase_aliases_file" } );
$logger->info( "Successfully read miRBase aliases." );

# Get site config with relevant variables.
my $atlasSiteConfig = AtlasSiteConfig->new->get_atlas_site_config;

# Array of miRNA array design accessions.
my $arrayDesignAccessions = $atlasSiteConfig->get_mirna_array_design_accessions
	or $logger->logdie( "Could not find mirna_array_design_accessions in YAML config." );

# Path to array designs directory on FTP site.
my $arrayDesignsFTPsite = $atlasSiteConfig->get_array_designs_ftp_site 
	or $logger->logdie( "Could not find array_designs_ftp_site in YAML config." );

# Path to directory to write mappings into.
my $writeDirectory = $atlasSiteConfig->get_mirbase_mappings_write_directory
	or $logger->logdie( "Could not find mirbase_mappings_write_directory in YAML config." );

# Add atlas prod directory to path for writing.
$writeDirectory = File::Spec->catdir( $atlasProdDir, $writeDirectory );

# Go through the array design accessions...
foreach my $arrayDesignAccession ( @{ $arrayDesignAccessions } ) {

	$logger->info( "Mapping array design $arrayDesignAccession" );
	
	# Parse the ADF using the Bio::MAGETAB parser.
	my $parsedADF = &getParsedADF( $arrayDesignAccession, $arrayDesignsFTPsite );
	
	# Get reporter names and miRBase IDs from the ADF.
	my $reporterNamesToMirbaseIds = &getAdfReportersAndMirbaseIds( $parsedADF );
	
	# Map the reporter names to the correct miRBase accessions.
	my $mappedReporters = &mapReportersToMirbase( $reporterNamesToMirbaseIds );

	# Write out the mappings.
	&writeMappings( $writeDirectory, $arrayDesignAccession, $mappedReporters );
	
}
# end
#####


#############
# Subroutines

sub parse_args {

	my %args;

	my $want_help;

	GetOptions(
		"h|help"			=> \$want_help,
		"m|mirbase-aliases=s" => \$args{ "mirbase_aliases_file" },
	);

	if( $want_help ) {
		pod2usage(
			-exitval => 255,
			-output => \*STDOUT,
			-verbose => 1
		);
	}

	# We have to have the filename containing miRBase aliases otherwise we
	# can't continue.
	unless( $args{ "mirbase_aliases_file" } ) {
		pod2usage(
			-message => "You must provide the path to the file containing miRBase aliases (usually called \"aliases.txt\").\n",
			-exitval => 255,
			-output => \*STDOUT,
			-verbose => 1
		);
	}

	# If we got here, that means we were passed a filename for the miRBase
	# aliases. Check that it exists.
	unless( -e $args{ "mirbase_aliases_file" } ) {

		my $message = "The aliases file \"" . $args{ "mirbase_aliases_file" } . "\" cannot be found. Please check that it exists.\n";

		pod2usage(
			-message => $message,
			-exitval => 255,
			-output => \*STDOUT,
			-verbose => 1
		);
	}

	return \%args;
}


sub get_log_file_name {

	my $logFileName = "mirna_arraydesigns_to_mirbase_".$$.".log";

	return $logFileName;
}

sub get_log_file_header {

	my $headerText = "Mapping miRNA array design probe IDs to miRBase accessions"
		. "\nLog created at "
		. DateTime->now;
	
	$headerText .= "\n" . ( "-" x 80 ) . "\n\n";

	return $headerText;
}


sub make_mirbase_aliases {

	my ( $mirbaseAliasesFile ) = @_;

	# Empty hash for the aliases.
	my $mirbaseAliases = {};

	# Open the aliases file.
	open( my $fh, "<", $mirbaseAliasesFile ) 
		or $logger->logdie( "Cannot open \"$mirbaseAliasesFile\": $!" );
	
	# Go through it line-by-line...
	while( defined( my $line = <$fh> ) ) {
		
		# Split on tabs to get the accession and the other ID(s).
		my ( $mirbaseAccession, $joinedIDs ) = split "\t", $line;

		# If this is not a mature miRNA, skip it.
		unless( $mirbaseAccession =~ /^MIMAT/ ) { next; }

		# Split the IDs on semicolons.
		my @identifiers = split ";", $joinedIDs;

		# Go through the IDs...
		foreach my $id ( @identifiers ) {
			
			# Add each one to the hash as a key, with the accession as the
			# value.
			$mirbaseAliases->{ $id } = $mirbaseAccession;
		}
	}

	# Close the file.
	close $fh;

	# Return the hash we created.
	return $mirbaseAliases;
}


sub getParsedADF {
	
	my ( $arrayDesignAccession, $arrayDesignsFTPsite ) = @_;

	# First need four-letter pipeline code (MEXP, MTAB, GEOD, ...).
	( my $pipeline = $arrayDesignAccession ) =~ s/^A-(\w{4})-\d+/$1/;

	# Create ADF file path.
	my $adfFilename = File::Spec->catfile( $arrayDesignsFTPsite, $pipeline, $arrayDesignAccession, "$arrayDesignAccession.adf.txt" );
	
	$logger->info( "Parsing ADF" );

	my $adfParser = Bio::MAGETAB::Util::Reader::ADF->new({
		uri => $adfFilename,
	});
	my $parsedADF = $adfParser->parse();

	return $parsedADF;
}


sub getAdfReportersAndMirbaseIds {

	my ( $parsedADF ) = @_;

	# Get the designElements attribute. This is an array of objects
	# representing probes or probe sets on the microarray.
	my $designElements = $parsedADF->get_designElements;

	my $adfReporterNamesToMirbaseIds = {};

	# Go through them and look for miRBase accessions 
	foreach my $de ( @{ $designElements } ) {
		
		# Variable for Bio::MAGETAB::Reporter object.
		my $reporter;
		
		# If this array design has Bio::MAGETAB::Feature objects, get the
		# Bio::MAGETAB::Reporter from it.
		if( $de->isa( "Bio::MAGETAB::Feature" ) ) { $reporter = $de->get_reporter; } 
		# Otherwise, the design element is probably already a
		# Bio::MAGETAB::Reporter.
		else { $reporter = $de; }

		# If we have something other than a Bio::MAGETAB::Reporter here, don't
		# know what to do with it, so quit.
		unless( $reporter->isa( "Bio::MAGETAB::Reporter" ) ) {
			$logger->logdie( 
				"Don't know how to handle designElements of type ", 
				ref( $reporter )
			);
		}
		
		# Get the groups attribute. If it's missing, we can't continue, so die.
		my $reporterGroups = $reporter->get_groups 
			or $logger->logdie( "Cannot get reporter groups to determine probe category (i.e. control or experimental)." );

		# Now we have the group(s), find the 'role' group. Again, die if it's unavailable.
		my $roleGroup = undef;
		foreach my $reporterGroup ( @{ $reporterGroups } ) {	
			if( $reporterGroup->get_category =~ /^role$/i ) { $roleGroup = $reporterGroup; }
		}
		unless( $roleGroup ) {
			$logger->logdie( "Cannot find reporter group \"role\" to determine probe category (i.e. control or experimental)." );
		}

		# Now we have the role group, see if this is experimental or control.
		# If it's control, skip this probe.
		unless( $roleGroup->get_value =~ /^experimental$/i ) { next; }

		# Get the database entry object(s) for this reporter.
		my $dbEntries = $reporter->get_databaseEntries
			or $logger->logdie( "Cannot find any database entries for experimental reporter ", 
				$reporter->get_name,
				" -- so cannot get miRBase identifier." );

		# Get the database entry object for miRBase.
		my $mirbaseDBentry = undef;
		foreach my $dbEntry ( @{ $dbEntries } ) {
			
			my $termSource = $dbEntry->get_termSource;

			if( $termSource->get_name =~ /mirbase/i ) {
				$mirbaseDBentry = $dbEntry;
			}
		}
		
		# Check that we got a database entry object for miRBase. If not, die.
		unless( $mirbaseDBentry ) {
			$logger->logdie( "Cannot find miRBase database entry for experimental reporter ",
				$reporter->get_name,
				" -- so cannot get miRBase identifier." );
		}
			
		# Now we have the miRBase database entry, we can get the identifier
		# stored in the 'accession' attribute. This is not necessarily what
		# miRBase refers to as an 'accession', so we may still need to do some
		# mapping with the miRBase aliases file later.
		my $mirbaseID = $mirbaseDBentry->get_accession;
	
		# Get the reporter name.
		my $reporterName = $reporter->get_name;
		
		$adfReporterNamesToMirbaseIds->{ $reporterName } = $mirbaseID;
	}

	return $adfReporterNamesToMirbaseIds;
}


sub mapReportersToMirbase {

	my ( $reporterNamesToMirbaseIds ) = @_;

	# Count how many reporter names we start with.
	my $beforeMappingCount = (keys %{ $reporterNamesToMirbaseIds } );

	$logger->info( "Starting with $beforeMappingCount reporters." );

	# The miRBase IDs in the ADF may be either miRBase stable accessions (e.g.
	# MIMAT0002177) or miRBase identifiers (e.g. hsa-miR-486-5p).  If we've
	# already got stable accessions, then we can just use those for the
	# mapping. If not, we need to replace the IDs we found in the ADF with
	# their stable ID, which is found in the aliases file.
	foreach my $reporterName ( keys %{ $reporterNamesToMirbaseIds } ) {

		# Look at the format of the miRBase ID. If it's "MIMAT" followed by
		# numbers, keep it. If it's just "MI" and then numbers, we can discard
		# it as it does not represent a mature miRNA, and we only want to keep
		# mature ones. If it's something else, then look in the aliases and see
		# if we have a mapping.

		my $adfMirbaseId = $reporterNamesToMirbaseIds->{ $reporterName };

		if( $adfMirbaseId =~ /^MIMAT\d+$/ ) { next; }
		
		elsif( $adfMirbaseId =~ /^MI\d+$/ ) {
			delete $reporterNamesToMirbaseIds->{ $reporterName };
		}

		else {
			my $mirbaseAccession = $mirbaseAliases->{ $adfMirbaseId };
			
			# Add the accession in place of the ID, if we found one in the aliases.
			if( $mirbaseAccession ) {
				$reporterNamesToMirbaseIds->{ $reporterName } = $mirbaseAccession;
			}
			# Otherwise, log and go to the next one.
			else {
				$logger->warn( "No miRBase accession found in aliases for ID \"",
					$adfMirbaseId,
					"\" (reporter name \"",
					$reporterName,
					"\""
				);
				
				delete $reporterNamesToMirbaseIds->{ $reporterName };
			}
		}
	}

	# Count how many reporter names we are left with after mapping.
	my $afterMappingCount = (keys %{ $reporterNamesToMirbaseIds } );

	my $percentageRemoved = 100 * ( ( $beforeMappingCount - $afterMappingCount ) / $beforeMappingCount );
	$percentageRemoved = nearest( .01, $percentageRemoved );

	$logger->info( "After mapping there are $afterMappingCount reporters left ( $percentageRemoved% reporters removed )." );

	return $reporterNamesToMirbaseIds;
}


sub writeMappings {

	my ( $writeDirectory, $arrayDesignAccession, $mappedReporters ) = @_;

	# Directory to write mappings file to.
	my $arrayDesignDirectory = File::Spec->catfile( $writeDirectory, $arrayDesignAccession );
	
	# See if it already exists. If not, create it.
	unless( -e $arrayDesignDirectory ) {
		$logger->info( "Creating new directory for $arrayDesignAccession" );
		`mkdir $arrayDesignDirectory`;
	}
	
	# Create filename for output.
	my $mappingFilename = $arrayDesignAccession . "_reporter_mirbase_probename.txt";
	$mappingFilename = File::Spec->catfile( $arrayDesignDirectory, $mappingFilename );

	$logger->info( "Writing mappings to $mappingFilename" );

	# Open file for writing.
	open( my $fh, ">", $mappingFilename ) or $logger->logdie( "Cannot create output file \"$mappingFilename\": $!" );

	# Write headers.
	printf $fh "mirna\tdesign_element";

	# Write the mappings.
	foreach my $reporterName ( keys %{ $mappedReporters } ) {

		my $line = join "\t", ( $mappedReporters->{ $reporterName }, $reporterName );
		$line = "\n$line";

		print $fh $line;
	}

	$logger->info( "Mappings for $arrayDesignAccession written successfully" );
}
