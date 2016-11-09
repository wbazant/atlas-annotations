
//val allSpecies = readProperties(annsrcsPath).map(_.species).toSet


//groups by value of property
//val groupsByValue = readProperties(annsrcsPath).filter(!isAboutArrayDesign(_)).groupBy(_.name).mapValues(_.groupBy(_.value)).mapValues(_.mapValues(_.map(_.species)))
//browse(groupsByValue)

/*
Fragmented values:
@ res73.map{case (propertyName, m) => (propertyName,m.values.map{_.size})}.toList.sortBy{case t => t._2.sum - t._2.size*1000}
res80: List[(String, Iterable[Int])] = List(
  ("datasetName", List(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)),
  ("mySqlDbName", List(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)),
  ("organism", List(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2)),
  ("chromosomeName", List(1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1)),
  ("property.ortholog", List(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)),
  ("property.uniprot", List(1, 24, 19, 5)),
  ("databaseName", List(26, 4, 17, 3)),
  ("url", List(26, 4, 4, 17)),
  ("software.name", List(26, 4, 17, 4)),
  ("property.refseq", List(14, 5, 19)),
  ("property.mirbase_id", List(1, 19)),
  ("mySqlDbUrl", List(26, 24)),
  ("property.go", List(24, 26)),
  ("property.symbol", List(26, 24)),
  ("property.interpro", List(24, 26)),
  ("property.goterm", List(26, 24)),
  ("property.ensgene", List(50, 1)),
  ("software.version", List(25, 26))
Unique values:
("property.ensprotein", List(50)),
("property.enstranscript", List(50)),
("property.interproterm", List(50)),
("property.description", List(50)),
("property.gene_biotype", List(50)),
("types", List(50)),
("property.entrezgene", List(39)),
("property.embl", List(27)),
("property.ensfamily", List(26)),
("property.ensfamily_description", List(26)),
("property.unigene", List(25)),
("property.mirbase_accession", List(20)),
("property.hgnc_symbol", List(14)),
("property.poterm", List(4)),
("property.po", List(4)),
("property.mgi_symbol", List(1)),
("property.flybase_transcript_id", List(1)),
("property.rgd_symbol", List(1)),
("property.flybasename_transcript", List(1)),
("property.rgd", List(1)),
("property.mgi_description", List(1)),
("property.mgi_id", List(1)),
("property.flybase_gene_id", List(1)),




groupsByValue.map{_._2.filter{_._2.toSet.size>40}.mapValues(_.toSet.size)}.filter(!_.isEmpty)

//all but worms have these agreeing on each other:
groupsByValue.map{_._2.filter{_._2.toSet.size>40}.mapValues(_.toSet)}.filter(!_.isEmpty).map{_.mapValues{allSpecies -- _}}
res59: collection.immutable.Iterable[Map[String, Set[String]]] = List(
  Map("ensembl_peptide_id" -> Set("caenorhabditis_elegans")),
  Map("ensembl_transcript_id" -> Set("caenorhabditis_elegans")),
  Map("interpro_description" -> Set("caenorhabditis_elegans")),
  Map("description" -> Set("caenorhabditis_elegans")),
  Map("gene_biotype" -> Set("caenorhabditis_elegans")),
  Map("ensembl_gene_id" -> Set("caenorhabditis_elegans")),
  Map("ensgene,enstranscript,ensprotein" -> Set("caenorhabditis_elegans"))
)

Next in completeness is
Map(
    "entrezgene" -> Set(
      "yarrowia_lipolytica",
      "schizosaccharomyces_pombe",
      "medicago_truncatula",
      "caenorhabditis_elegans",
      "ciona_savignyi",
      "saccharomyces_cerevisiae",
      "musa_acuminata",
      "populus_trichocarpa",
      "dasypus_novemcinctus",
      "solanum_lycopersicum",
      "aspergillus_fumigatus",
      "oryza_rufipogon"
    )
  )
*/
