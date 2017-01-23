/*
Check the annotations prescribe the retrieval of data we need.
- All array designs specified in processing directories are also in the annotations
*/

import $file.^.^.experiment.ExperimentDirectory

import $file.^.^.property.AnnotationSource

private def arrayDesignsMissingFromAnnotationSources = {
  val arrayDesignsPresent =
    AnnotationSource.properties
    .flatMap(_.getAsArrayDesignAccession)
    .toSet

  ExperimentDirectory.allArrayDesigns
  .collect {
    case (arrayDesigns, experimentAccessions) if ! (arrayDesigns.toSet -- arrayDesignsPresent).isEmpty
      => s"${(arrayDesigns.toSet -- arrayDesignsPresent).mkString(", ")} missing from annotations but required for experiments ${experimentAccessions.mkString(", ")}"
  }
}

def annotationSourcesHaveAdequateArrayDesigns = {
  arrayDesignsMissingFromAnnotationSources match {
    case List()
      => Right(())
    case errs
      => Left(errs.mkString("\n"))
  }
}
