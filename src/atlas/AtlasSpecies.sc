import $ivy.`org.json4s:json4s-native_2.11:3.5.0`
import org.json4s._
import org.json4s.native.JsonMethods._
import org.json4s.JsonDSL._
import $file.^.property.AnnotationSource
import AnnotationSource.AnnotationSource
import $file.^.Directories
import $file.^.util.Combinators
import java.nio.file.{Paths, Files}
import java.nio.charset.StandardCharsets
import ammonite.ops._

case class AtlasSpecies(species: String, defaultQueryFactorType: String, kingdom: String, resources: List[(String, List[String])]) {
  val json =
    ("name" -> this.species) ~
    ("defaultQueryFactorType" -> this.defaultQueryFactorType) ~
    ("kingdom" -> this.kingdom) ~
    ("resources" ->
      this.resources.map { case (rType, rValues) =>
        (("type" -> rType) ~
         ("urls" -> rValues))})

  def toJson: String = pretty(render(json))
}

object AtlasSpeciesFactory {
  val defaultQueryFactorTypesMap =
    Map("parasite" -> "DEVELOPMENTAL_STAGE").withDefaultValue("ORGANISM_PART")

  val kingdomMap =
    Map("ensembl" -> "animals",
        "metazoa" -> "animals",
        "fungi" -> "fungi",
        "parasite" -> "animals",
        "plants" -> "plants")

  val resourcesMap =
    Map("genome_browser" ->  Map("ensembl" -> List("http://www.ensembl.org/"),
                                  "metazoa" -> List("http://metazoa.ensembl.org/"),
                                  "fungi" -> List("http://fungi.ensembl.org/"),
                                  "parasite" -> List("http://parasite.wormbase.org/"),
                                  "plants" -> List("http://plants.ensembl.org/", "http://ensembl.gramene.org/"))
    )

  def create(annotationSource: AnnotationSource): Either[String, AtlasSpecies] = {
    AnnotationSource.getValues(annotationSource, List("databaseName", "mySqlDbName"))
    .right.map {
      case List(databaseName, mySqlDbName) =>
        AtlasSpecies(
          speciesName(annotationSource),
          defaultQueryFactorTypesMap(databaseName),
          kingdomMap(databaseName),
          resourcesMap.toList.map {
            case (key, values) => (key, values(databaseName).map(_ + mySqlDbName.capitalize))
          }
        )
    }
  }
}

def speciesName(annotationSource: AnnotationSource) = annotationSource.segments.last.capitalize

def atlasSpeciesFromAllAnnotationSources = {
  Combinators.combine(
    Directories.annotationSources
    .groupBy{speciesName}
    .map {
      case (speciesName, annotationSourcesForSpecies)
        => Combinators.combineAny(
            annotationSourcesForSpecies.map(AtlasSpeciesFactory.create)
          ).right.map {
            _.head //unsafe but okay because combineAny guarantees there will be results
          }
    }
  )
}

@main
def dump() : Unit = {
  atlasSpeciesFromAllAnnotationSources
  .right.map(_.toList.sortBy(_.species))
  .right.map(_.map(_.toJson).mkString(",\n"))
  .right.map {
    case txt => s"[${txt}]"
  } match {
      case Right(res) => System.out.print(res)
      case Left(err) => System.err.println(err)
  }
}
