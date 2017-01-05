# atlas-annotations


This is a repository for scripts that we use for retrieving annotations used by Atlas Solr searches and more.
It also stores the config of Atlas properties per species name and which public BioMart database we retrieve it from.

### Entry points

`sh/ensembl/ensemblUpdate.sh`
the entry point to the whole process

`sh/atlas-species.sh`
Regenerate the species file based on annotation sources config
