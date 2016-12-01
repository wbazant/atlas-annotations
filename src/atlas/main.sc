import $file.AtlasSpecies
import $file.^.Directories

val speciesJsonPath = Directories.scriptOutDestination("species.json")
if(speciesJsonPath.toNIO.toFile.exists){
  val swp = Directories.scriptOutDestination("species.json.swp")
  swp.toNIO.toFile.delete
  ammonite.ops.mv(speciesJsonPath, swp)
}

AtlasSpecies.dump(Directories.scriptOutDestination("species.json"))
