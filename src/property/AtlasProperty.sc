import $file.AnnotationSource

sealed abstract class AtlasProperty(val annotationSource: AnnotationSource.AnnotationSource, val atlasName: String)

case class AtlasBioentityProperty(override val annotationSource: AnnotationSource.AnnotationSource,val bioentityType: AnnotationSource.Property, override val atlasName: String) extends AtlasProperty(annotationSource,atlasName)

case class AtlasArrayDesign(override val annotationSource: AnnotationSource.AnnotationSource,override val atlasName: String) extends AtlasProperty(annotationSource,atlasName)

private def atlasBioentityProperties(atlasName: String,ensemblNames: List[String], annotationSource: AnnotationSource.AnnotationSource) = {
  AnnotationSource.getBioentityTypeProperties(annotationSource)
  .fold(l => List(), r => r.map {
    case bioentityType =>
      new AtlasBioentityProperty(annotationSource, bioentityType, atlasName) -> ensemblNames.filter(_!=bioentityType.value)
  })
  .filter {
    case (_, List())
      => false
    case _
      => true
  }
  .toMap
}

def getMappingWithDesiredCorrespondingProperties = {
  AnnotationSource.properties
  .filter{case p: AnnotationSource.Property =>
    ! p.isBioentityType
  }
  .map{case p: AnnotationSource.Property =>
    val ensemblNames = p.value.split(",").toList
    p.name.split("\\.").toList match {
      case List("property", atlasName)
        =>  atlasBioentityProperties(atlasName, ensemblNames, p.annotationSource)
      case List("arrayDesign", arrayDesign)
        => Map(
          new AtlasArrayDesign(p.annotationSource, arrayDesign) -> ensemblNames
        )
      case _
        => Map()
    }
  }.reduceLeft(_ ++ _)

}
