import $file.^.property.AtlasProperty
import AtlasProperty._
import $file.^.Directories
import Directories._

import ammonite.ops._

def writeResult(destination: Path, result: Stream[String], hasErrors: Boolean = false) = {
  if(hasErrors) {
    write.over(destination / up / (destination.last+".failed"), result)
  } else {
    val swp = destination/ up / (destination.last+".swp")
    write.over(swp, result)
    mv(swp, destination)
  }
}

def destinationFor(atlasProperty: AtlasProperty) = {
  val middleBit =
    atlasProperty match {
      case AtlasBioentityProperty(species, bioentityType, atlasName)
        => s".${bioentityType.name.replace("property.", "")}."
      case AtlasArrayDesign(species, atlasName)
        => "."
    }
  ATLAS_PROD / "bioentity_properties" / atlasProperty.annotationSource.segments.reverse.apply(1) / s"${atlasProperty.annotationSource.segments.last}${middleBit}${atlasProperty.atlasName}.tsv"
}
