import $file.AtlasSpecies
import $file.^.Paths

val speciesJsonPath = Paths.scriptOutDestination("species.json")
if(speciesJsonPath.toNIO.toFile.exists){
  val swp = Paths.scriptOutDestination("species.json.swp")
  swp.toNIO.toFile.delete
  ammonite.ops.mv(speciesJsonPath, swp)
}

AtlasSpecies.dump(Paths.scriptOutDestination("species.json"))
