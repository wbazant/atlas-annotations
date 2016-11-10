import $file.AnnotationSource

import $file.Species
import Species.Species

sealed abstract class AtlasProperty(val species: Species, val atlasName: String)

case class AtlasBioentityProperty(override val species: Species, bioentityType: BioentityType, override val atlasName: String) extends AtlasProperty(species,atlasName)

sealed abstract class BioentityType(val ensemblName: String)
case object GENE extends BioentityType("ensembl_gene_id")
case object TRANSCRIPT extends BioentityType("ensembl_transcript_id")
case object PROTEIN extends BioentityType("ensembl_peptide_id")

case class AtlasArrayDesign(override val species: Species,override val atlasName: String) extends AtlasProperty(species,atlasName)

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
            new AtlasBioentityProperty(p.species, GENE, atlasName) -> ensemblNames,
            new AtlasBioentityProperty(p.species, TRANSCRIPT, atlasName) -> ensemblNames,
            new AtlasBioentityProperty(p.species, PROTEIN, atlasName) -> ensemblNames
          )
        }
      case List("arrayDesign", arrayDesign)
        => Map(
          new AtlasArrayDesign(p.species, arrayDesign) -> ensemblNames
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
