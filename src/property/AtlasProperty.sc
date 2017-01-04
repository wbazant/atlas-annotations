import $file.AnnotationSource

import $file.Species
import Species.Species

sealed abstract class AtlasProperty(val annotationSource: ammonite.ops.Path, val atlasName: String) {
  def species : String = annotationSource.segments.last
}

case class AtlasBioentityProperty(override val annotationSource: ammonite.ops.Path, bioentityType: BioentityType, override val atlasName: String) extends AtlasProperty(annotationSource,atlasName)

/*
TODO: these are different for wormbase central, study Maria's code to see how she went around it
*/
sealed abstract class BioentityType(val ensemblName: String)
case object GENE extends BioentityType("ensembl_gene_id")
case object TRANSCRIPT extends BioentityType("ensembl_transcript_id")
case object PROTEIN extends BioentityType("ensembl_peptide_id")

case class AtlasArrayDesign(override val annotationSource: ammonite.ops.Path,override val atlasName: String) extends AtlasProperty(annotationSource,atlasName)

def getMappingWithEnsemblProperties = {
  AnnotationSource.properties
  .filter{case p: AnnotationSource.Property =>
    ! List(GENE.ensemblName, PROTEIN.ensemblName, TRANSCRIPT.ensemblName).contains(p.value)
  }
  .map{case p: AnnotationSource.Property =>
    val ensemblNames = p.value.split(",").toList
    p.name.split("\\.").toList match {
      case List("property", atlasName)
        =>  {
          Map(
            new AtlasBioentityProperty(p.annotationSource, GENE, atlasName) -> ensemblNames,
            new AtlasBioentityProperty(p.annotationSource, TRANSCRIPT, atlasName) -> ensemblNames,
            new AtlasBioentityProperty(p.annotationSource, PROTEIN, atlasName) -> ensemblNames
          )
        }
      case List("arrayDesign", arrayDesign)
        => Map(
          new AtlasArrayDesign(p.annotationSource, arrayDesign) -> ensemblNames
        )
      case _
        => Map()
    }
  }.reduceLeft(_ ++ _)

}

def allEnsemblPropertiesForSpecies(species:String) = {
  getMappingWithEnsemblProperties
  .filter{ case ap: AtlasProperty =>
    ap.species == species
  }
  .values.flatten.toSet
}
