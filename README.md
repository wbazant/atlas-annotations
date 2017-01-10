# atlas-annotations


This is a repository for scripts that we use for retrieving annotations used by Atlas Solr searches and more.
It also stores the config of Atlas properties per species name and which public BioMart database we retrieve it from.

### Dependencies
src - only java and [Ammonite](http://www.lihaoyi.com/Ammonite/)
ensemblUpdate.sh - various bash utilities,mysql, environment variable $ATLAS_PROD (see util/create_test_env.sh to work with this script)

### Structure

#### ./annsrcs
Annotation source files describing the mapping of Atlas properties we want to foreign properties with sources of their retrieval

#### ./sh
Executables that the Atlas development team runs to update their annotations

#### ./src
Scala (Ammonite) source code of the process where we will aim to migrate the logic to

#### ./util
Tools that make the Atlas team's work easier, including scripts to automatically update the annotation sources

### Entry points

`sh/ensembl/ensemblUpdate.sh`
the entry point to the whole process

`sh/atlas_species.sh`
Regenerate the species file based on annotation sources config
