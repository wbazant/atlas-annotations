import $ivy.`org.json4s:json4s-native_2.11:3.5.0` 
import org.json4s._
import org.json4s.native.JsonMethods._
import org.json4s.JsonDSL._
import $file.property.AnnotationSource
import $file.property.Species
import java.nio.file.{Paths, Files} 
import java.nio.charset.StandardCharsets 

case class AtlasSpecies(species: String, defaultQueryFactorType: String, kingdom: String, resources: List[(String, List[String])]) {
  val json =
    ("atlasSpecies" -> ("name" -> this.species) ~
    ("defaultQueryFactorType" -> this.defaultQueryFactorType) ~
    ("kingdom" -> this.kingdom) ~
    ("resources" ->
      this.resources.map { case (rType, rValues) =>
        (("type" -> rType) ~
         ("url" -> rValues))}))

  def toJson: String = pretty(render(json))
}

object AtlasSpeciesFactory {
  val defaultQueryFactorTypesMap = Map("parasite" -> "DEVELOPMENTAL_STAGE")

  val kingdomMap =
    Map("ensembl" -> "animals",
        "metazoa" -> "animals",
        "fungi" -> "fungi",
        "parasite" -> "animals",
        "plants" -> "plants")

  val resourcesMap = 
    Map("genome browser" ->  Map("ensembl" -> List("http://www.ensembl.org/"),
                                  "metazoa" -> List("http://metazoa.ensembl.org/"),
                                  "fungi" -> List("http://fungi.ensembl.org/"),
                                  "parasite" -> List("http://parasite.wormbase.org/"),
                                  "plants" -> List("http://plants.ensembl.org/", "http://ensembl.gramene.org/"))
    )

  def create(species: String): AtlasSpecies = {
    AnnotationSource.getValues(species, List("databaseName", "mySqlDbName")) match {
      case Right(List(databaseName, mySqlDbName)) => 
        AtlasSpecies(
          species,
          defaultQueryFactorTypesMap.get(databaseName).getOrElse("ORGANISM_PART"),
          kingdomMap.get(databaseName).getOrElse(""),
          resourcesMap.toList.map {
            case (key, values) => (key, values.get(databaseName).getOrElse(List()).map(_ + mySqlDbName))
          }
        )
    }
  }
}

// object Main extends App {
  val allSpeciesJson = Species.allSpecies.map(AtlasSpeciesFactory.create).map(_.toJson)

  val filePath = "species.json"
  val str = "[" + allSpeciesJson.mkString(",\n") + "]"
  Files.write(Paths.get(filePath), str.getBytes(StandardCharsets.UTF_8))
// }
