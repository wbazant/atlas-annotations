interp.load.ivy("org.scalaj" %% "scalaj-http" % "2.2.0")
import scalaj.http._
import scala.xml.XML
import scala.util.{Try, Success, Failure}

import $file.Combinators
import Combinators.Species
import $file.Annsrcs


def request(databaseName: String,properties: Map[String, String]) : HttpRequest = {
  val base = databaseName match {
    case "metazoa" => "http://metazoa.ensembl.org"
    case "plants" => "http://plants.ensembl.org"
    case "fungi" => "http://fungi.ensembl.org"
    case _ => "http://www.ensembl.org"
  }
  Http(base+"/biomart/martservice").params(properties).timeout(connTimeoutMs = 5000, readTimeoutMs = 30000)
}

def getAsXml(request: HttpRequest): Either[String, xml.Elem] = {
  Try(request.asString)
  .filter{case response => !response.isError}
  .flatMap {
    case response
      => Try(XML.loadString(response.body))
  } match {
      case Success(r)
       => Right(r)
      case Failure(e)
        => Left(e.toString)
  }
}

def registryRequest(species: Species) = {
  Annsrcs.getValue(species, "databaseName")
  .right.map {
    case (databaseName)
      => request(databaseName, Map("type"->"registry"))
  }
}


def availableMartsAndTheirSchemas(responseXml: xml.Elem) = {
  (responseXml \\ "MartURLLocation")
  .map{case x =>
    (x.attribute("database"),x.attribute("serverVirtualSchema")) match {
      case (Some(db),Some(serverVirtualSchema))
        => Some((db.toString,serverVirtualSchema.toString))
      case _
        => None
    }
  }
  .flatten
  .toMap
}

def lookupAvailableMartsAndTheirSchemas(species: Species) : Either[String, Map[String, String]] = {
  registryRequest(species)
  .right.map {
    case (req)
      => getAsXml(req)
  }.joinRight
  .right.map {
    case xml
      => availableMartsAndTheirSchemas(xml)
  }
}

def lookupServerVirtualSchema(species: Species) :Either[String,String]  = {
  Annsrcs.getValues(species, List("software.name", "software.version"))
  .right.map {
    case params => params match {
      case List(softwareName, softwareVersion)
        => lookupAvailableMartsAndTheirSchemas(species)
            .right.flatMap { case marts =>
              marts
              .get(s"${softwareName}_mart_${softwareVersion}")
              .toRight(s"Could not determine serverVirtualSchema for species ${species} because expected mart not found, available marts: ${marts.mkString(", ")}")
            }
      case x
        => Left(s"Unexpected: ${x}")
    }
  }.joinRight
}

//TODO: databaseName and datasetName might be per kingdom (metazoa,fungi, etc.)
def attributesRequest(species:String) = {
  Annsrcs.getValues(species, List("databaseName", "datasetName"))
  .right.flatMap {
    case params => params match {
      case List(databaseName, datasetName)
        => Right(request(databaseName, Map("type"->"attributes", "dataset"-> datasetName)))
      case x
        => Left(s"Unexpected: ${x}")
    }
  }
}

case class Attribute(propertyName: String, name: String ,kind: String, dbName: String, dbColumn: String)

object Attribute {
  def parse(tsvLine:String) : Option[Attribute] = {
    val cols = tsvLine.split('\t')
    if(cols.length == 7 && cols(4) == "html,txt,csv,tsv,xls"){
      val name = if (cols(2).length>0) {
        cols(1)+ "/ "+ cols(2)
      } else {
         cols(1)
       }
      Some(Attribute(cols(0), name , cols(3), cols(5), cols(6)))
    } else {
      None
    }
  }
}

/*
e.g.
Attribute("ensembl_gene_id", "Ensembl Gene ID/ Ensembl Stable ID of the Gene", "feature_page", "btaurus_gene_ensembl__gene__main", "stable_id_1023"),
Attribute("ensembl_transcript_id", "Ensembl Transcript ID/ Ensembl Stable ID of the Transcript", "feature_page", "btaurus_gene_ensembl__transcript__main", "stable_id_1066"),
*/
def lookupAttributes(species:String) = {
  attributesRequest(species)
  .right.flatMap {case request =>
    Try(request.asString)
    .filter {case response => !response.isError}
      match {
        case Success(r)
         => Right(r.body)
        case Failure(e)
          => Left(e.toString)
    }
  }.right.map {case body =>
    body
    .split('\n')
    .map(Attribute.parse(_))
    .flatten
  }
}

//replaces: curl -s -X GET "${url}type=attributes&dataset=${datasetName}" | awk '{print $1}' | sort | uniq > ${f}.ensemblproperties
def validateEnsemblPropertiesInOurConfigCorrespondToBioMartAttributes(species: Species) = {
  lookupAttributes(species)
  .right.map {
    _
    .map{_.propertyName}
    .toSet
  }.right.flatMap { case bioMartAttributes =>
    (Annsrcs.allEnsemblBioentityProperties(species) -- bioMartAttributes.toSet).toList match {
      case List()
        => Right(())
      case x
        => Left(s"Properties in our config for species ${species} not found as BioMart attributes: ${x.mkString(", ")}")
    }
  }
}

def validate() = {
  Combinators.doAll(validateEnsemblPropertiesInOurConfigCorrespondToBioMartAttributes)(Combinators.speciesList())
}






//ensembl_gene_id	Ensembl Gene ID	Ensembl Stable ID of the Gene	feature_page	html,txt,csv,tsv,xls	btaurus_gene_ensembl__gene__main	stable_id_1023

//Set("feature_page", "sequences", "snp", "structure", "homologs", "snp_somatic")

//    curl -s -X GET "${url}type=attributes&dataset=${datasetName}" | awk '{print $1}' | sort | uniq > ${f}.ensemblproperties

/*
serverVirtualSchema you need to look up
the other ones are properties
url is not quite an url, just like, "ensembl"

*/

//virtualSchemaName is not what I thought it is, I think!
//bioMartRequest(BiomartAuxiliaryInfo("ensembl","default", "btaurus_gene_ensembl"),Map(), List("ensembl_gene_id", "go_id")).asString

case class BiomartAuxiliaryInfo(databaseName: String, serverVirtualSchema: String, datasetName: String)

object BiomartAuxiliaryInfo {
  def getMap(speciesKeys: Seq[Species]) = { //: Either[String, Map[Species, BiomartAuxiliaryInfo ]]
    Combinators.combine(
      speciesKeys
      .map{ case species : Species =>
        getForSpecies(species)
        .right.map((species, _))
      }
    )
    .right.map(_.toMap)
    // speciesKeys
    // .toSet
    // .flatMap{ case species :Species => getFor(species).right.map((species, _))}
  }

  def getForSpecies(species: Species) = {
    Annsrcs.getValues(species, List("databaseName", "datasetName"))
    .right.flatMap {
      case params => params match {
        case List(databaseName, datasetName)
          => lookupServerVirtualSchema(species)
              .right.map{ case serverVirtualSchema =>
                BiomartAuxiliaryInfo(databaseName,serverVirtualSchema, datasetName)
              }
        case x
          => Left(s"Unexpected: ${x}")
      }
    }
  }
}

def bioMartRequest(
  biomartAuxiliaryInfo : BiomartAuxiliaryInfo,
  filters: Map[String, String],
  attributes: List[String]) = {
    val query =
      <Query
        virtualSchemaName={biomartAuxiliaryInfo.serverVirtualSchema}
        formatter="TSV"
        header="1"
        uniqueRows="1"
        count="0">
        <Dataset
          name={biomartAuxiliaryInfo.datasetName}
          interface="default">
          {filters
            .map {case (k,v) =>
              <Filter name={k} value={v} />
            }
          }
          {attributes
           .map {case attr =>
             <Attribute name={attr} />
            }
          }
        </Dataset>
      </Query>

  request(biomartAuxiliaryInfo.databaseName, Map(("query","<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE Query>"+ query.toString))
  )
}

def fetchFromBioMart(aux:Map[Species, BiomartAuxiliaryInfo])(species: Species, filters: Map[String, String], attributes: List[String]) : Either[String, String]= {
  aux.get(species).map(Right(_))
  .getOrElse(BiomartAuxiliaryInfo.getForSpecies(species))
  .right.map{ case bioMartAuxiliaryInfo =>
    bioMartRequest(bioMartAuxiliaryInfo, filters, attributes)
  }
  .right.map { case request =>
    request.asString.body
  }
}

def fetchFromBioMart(species: Species, filters: Map[String, String], attributes: List[String]) : Either[String, String] = {
  fetchFromBioMart(Map[Species, BiomartAuxiliaryInfo]())(species, filters, attributes)
}





def fetchProperties(url: String, serverVirtualSchema: String, datasetName: String, ensemblBioentityType: String, ensemblProperty: String, chromosomeName: String) = ""
