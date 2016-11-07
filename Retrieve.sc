import $file.Annsrcs

case class RetrieveAnnotationTask(species: String, filters: Map[String, String], attributes: List[String])


def tasks(species: String) = {
  val ensemblBioentityTypes = Map(
    "ensgene"->"ensembl_gene_id",
    "ensprotein"->"ensembl_peptide_id",
    "enstranscript"-> "ensembl_transcript_id")

  val filters =
    Annsrcs.getValue(species,"chromosomeName")
    .right.map(_.split(",").toList) match {
    case Right(chromosomes)
      => {
        chromosomes
        .map { case chromosome =>
          Map("chromosomeName"->chromosome)
        }
      }
    case _
      => List(Map[String,String]())
  }
  for {
      bioentityType <- ensemblBioentityTypes.values
      filter <- filters
      propertyName<- Annsrcs.allEnsemblBioentityProperties(species)
      if( bioentityType!=propertyName)
  } yield {
    RetrieveAnnotationTask(species, filter, List(bioentityType, propertyName))
  }
}


/*
types=ensgene,enstranscript,ensprotein
property.description=description
property.embl=embl
property.ensfamily=family
property.ensfamily_description=family_description
property.ensgene=ensembl_gene_id
property.ensprotein=ensembl_peptide_id
*/
