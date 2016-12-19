import $file.AtlasSpecies
import $file.^.Directories

val speciesJsonPath = Directories.scriptOutDestination("species-properties.json")
if(speciesJsonPath.toNIO.toFile.exists){
  val swp = Directories.scriptOutDestination("species-properties.json.swp")
  swp.toNIO.toFile.delete
  ammonite.ops.mv(speciesJsonPath, swp)
}

AtlasSpecies.dump(Directories.scriptOutDestination("species-properties.json"))
