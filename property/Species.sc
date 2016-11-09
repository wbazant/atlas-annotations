import $file.AnnotationSource


type Species = String

def allSpecies() : Seq[Species] = ammonite.ops.ls(AnnotationSource.annsrcsPath).map(_.segments.last)


/*
TODO i just moved this, everything broke.

import $file.Species
import Species.Species

*/
