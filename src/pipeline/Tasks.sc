import $file.^.property.AtlasProperty
import AtlasProperty._
import $file.^.property.AnnotationSource
import $file.Paths

type BioMartQuerySpecification = (Map[String, String],List[String]) //filters and attributes
case class BioMartTask(species: String, queries: List[BioMartQuerySpecification], destination: ammonite.ops.Path){
  def seemsDone = destination.toNIO.toFile.exists
  def ensemblAttributesInvolved = queries.map(_._2).flatten.toSet
  override def toString = s"BioMart task for ${species} : ${queries.size} queries, destination: ${destination}"
}

def ensemblNameOfReferenceColumn(atlasProperty: AtlasProperty) = {
  atlasProperty match {
    case AtlasBioentityProperty(species, GENE, atlasName)
      => "ensembl_gene_id"
    case AtlasBioentityProperty(species, TRANSCRIPT, atlasName)
      => "ensembl_peptide_id"
    case AtlasBioentityProperty(species, PROTEIN, atlasName)
      => "ensembl_transcript_id"
    case AtlasArrayDesign(species, atlasName)
      => "ensembl_gene_id"
  }
}

def queriesForAtlasProperty(atlasProperty: AtlasProperty, ensemblProperties : List[String]) = {
  val shards =
      AnnotationSource.getValue(atlasProperty.species,"chromosomeName")
      .right.map(_.split(",").toList.map{case chromosome => Map("chromosome_name"->chromosome)})
      .left.map{missingChromosome => List(Map[String,String]())}
      .merge

  ensemblProperties
  .flatMap{case ensemblName =>
    val attributes =
      List(
        ensemblNameOfReferenceColumn(atlasProperty)
        ,ensemblName
      )

    shards.map((_,attributes))
  }
}

def retrievalPlanForAtlasProperty(atlasProperty: AtlasProperty, ensemblProperties : List[String]) = {
  BioMartTask(
    atlasProperty.species,
    queriesForAtlasProperty(atlasProperty, ensemblProperties),
    Paths.destinationFor(atlasProperty)
  )
}


def allTasks = {
  AtlasProperty.getMappingWithEnsemblProperties
  .map{ case (atlasProperty, ensemblProperties) =>
    retrievalPlanForAtlasProperty(atlasProperty, ensemblProperties)
  }
  .toSeq
}
