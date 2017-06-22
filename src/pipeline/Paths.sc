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

def destinationFor(atlasProperty: AtlasProperty) = directoryFor(atlasProperty) / fileNameFor(atlasProperty)

def fileNameFor(atlasProperty: AtlasProperty) = {
    atlasProperty match {
      case AtlasBioentityProperty(annotationSource, bioentityType, atlasName)
        => s"${annotationSource.segments.last}.${bioentityType.name.replace("property.", "")}.${atlasName}.tsv"
      case AtlasArrayDesign(annotationSource, atlasName)
        => s"${annotationSource.segments.last}.${atlasName}.tsv"
    }
}

def directoryFor(atlasProperty: AtlasProperty) = {
    atlasProperty match {
      case AtlasBioentityProperty(_,_,_)
        => ATLAS_PROD / "bioentity_properties" / atlasProperty.annotationSource.segments.reverse.apply(1)
      case AtlasArrayDesign(_, _)
        => ATLAS_PROD / "bioentity_properties" / "array_designs" / "current"
    }
}
