/*
Check the annotations prescribe the retrieval of data we need.
- All array designs specified in processing directories are also in the annotations
*/

import $file.^.^.experiment.ExperimentDirectory

import $file.^.^.property.AnnotationSource

import $file.^.^.Directories
import ammonite.ops._

def arrayDesignsBackfilled = {
    ls (Directories.ATLAS_PROD / "bioentity_properties" / "array_designs" / "backfill" )
    .map(_.name.split("\\.").toList)
    .collect {
        case _ :: arrayDesignAccession :: "tsv" :: List()
            => arrayDesignAccession
    }
}

private def arrayDesignsMissingFromAnnotationSources = {
  val arrayDesignsPresent =
    AnnotationSource.properties
    .flatMap(_.getAsArrayDesignAccession)
    .toSet ++ arrayDesignsBackfilled.toSet

  ExperimentDirectory.allArrayDesigns
  .collect {
    case (arrayDesigns, experimentAccessions) if ! (arrayDesigns.toSet -- arrayDesignsPresent).isEmpty
      => s"${(arrayDesigns.toSet -- arrayDesignsPresent).mkString(", ")} missing from annotations but required for experiments ${experimentAccessions.mkString(", ")}"
  }
}

private def annotationsRequiredForRedecorationMissingPerSpecies = {
  AnnotationSource.properties
  .groupBy(_.annotationSource.name) // file name of annotation corresponds to species name
  .mapValues(_.map(_.name).toSet)
  .mapValues(Set("property.go", "property.interpro", "property.symbol") -- _)
  .collect {
    case (species, l) if ! l.isEmpty
      => s"${l.mkString(", ")} missing for species ${species} but required for experiment decoration!"
  }
}

def main = {
  (arrayDesignsMissingFromAnnotationSources ++ annotationsRequiredForRedecorationMissingPerSpecies) match {
    case List()
      => Right(())
    case errs
      => Left(errs.mkString("\n"))
  }
}
