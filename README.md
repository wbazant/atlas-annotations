# atlas-annotations


This is a repository for scripts that we use for retrieving annotations used by Atlas Solr searches and more.
It also stores the config of Atlas properties per species name and which public BioMart database we retrieve it from.

### Dependencies
src - only java and [Ammonite](http://www.lihaoyi.com/Ammonite/)
ensemblUpdate.sh - various bash utilities,mysql, environment variable $ATLAS_PROD (see util/create_test_env.sh to work with this script)

### Entry points

`sh/ensembl/ensemblUpdate.sh`
the entry point to the annotations update process

`sh/atlas_species.sh`
Regenerate the species file based on annotation sources config

### Structure

#### ./annsrcs
Annotation source files describing the mapping of Atlas properties we want to foreign properties with sources of their retrieval

#### ./util
Tools that make the Atlas team's work easier, including scripts to automatically update the annotation sources

#### ./sh
Executables that the Atlas development team runs to update their annotations

#### ./src
Scala (Ammonite) source code

|  path  	|   what it does	|
|:-:	|:-:	|
|   `./src/pipeline/Start.sc`	|   entry point for fetching annotations	|
|   `./src/pipeline/is_ready/PropertiesAdequate.sc`	|  check annotation sources vs what we think needs to be in them (e.g. all array designs ) |
|   `./src/pipeline/retrieve`	|  fetch annotations - internals 	|
|  ` ./src/go/PropertiesFromOwlFile.sc`	|   Parse the go.owl for what we need	|
|   `./src/interpro/Parse.sc	`|   Parse the Interpro provided file	|
|  ` ./src/atlas/AtlasSpecies.sc`	|   Create the species config for the webapp	|
