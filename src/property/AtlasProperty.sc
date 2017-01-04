import $file.AnnotationSource

sealed abstract class AtlasProperty(val annotationSource: ammonite.ops.Path, val atlasName: String) {
  def species : String = annotationSource.segments.last
}

case class AtlasBioentityProperty(override val annotationSource: ammonite.ops.Path, bioentityType: BioentityType, override val atlasName: String) extends AtlasProperty(annotationSource,atlasName)

sealed abstract class BioentityType(val ensemblName: String)
case object GENE extends BioentityType("ensembl_gene_id")
case object TRANSCRIPT extends BioentityType("ensembl_transcript_id")
case object PROTEIN extends BioentityType("ensembl_peptide_id")

case class AtlasArrayDesign(override val annotationSource: ammonite.ops.Path,override val atlasName: String) extends AtlasProperty(annotationSource,atlasName)

def getMappingWithDesiredCorrespondingProperties = {
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
