import $file.AnnotationSource


type Species = String

def allSpecies() : Seq[Species] = {
  (ammonite.ops.ls(AnnotationSource.annsrcsPath).toList ::: ammonite.ops.ls(AnnotationSource.wbpsAnnsrcsPath).toList)
  .map(_.segments.last).distinct
}


/*
TODO i just moved this, everything broke.

import $file.Species
import Species.Species

*/
