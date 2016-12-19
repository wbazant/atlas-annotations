import $file.^.Directories


type Species = String

def allSpecies() : Seq[Species] = {
  (ammonite.ops.ls(Directories.annsrcsPath).toList ::: ammonite.ops.ls(Directories.wbpsAnnsrcsPath).toList)
  .map(_.segments.last).distinct
}


/*
TODO i just moved this, everything broke.

import $file.Species
import Species.Species

*/
