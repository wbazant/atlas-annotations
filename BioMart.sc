interp.load.ivy("org.scalaj" %% "scalaj-http" % "2.2.0")
import scalaj.http._
import scala.xml.XML
import scala.util.{Try, Success, Failure}

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

def registryRequest(species: String) = {
  Annsrcs.getValue(species, "databaseName")
  .right.map {
    case (databaseName)
      => request(databaseName, Map("type"->"registry"))
  }
}


def availableMarts(responseXml: xml.Elem) = {
  (responseXml \\ "MartURLLocation")
  .map{case x =>
    (x.attribute("database"),x.attribute("name")) match {
      case (Some(db),Some(name))
        => Some((db.toString,name.toString))
      case _
        => None
    }
  }
  .flatten
  .toMap
}

def lookupAvailableMarts(species: String) : Either[String, Map[String, String]] = {
  registryRequest(species)
  .right.map {
    case (req)
      => getAsXml(req)
  }.joinRight
  .right.map {
    case xml
      => availableMarts(xml)
  }
}

def lookupServerVirtualSchema(species: String) :Either[String,String]  = {
  Annsrcs.getValues(species, List("software.name", "software.version"))
  .right.map {
    case params => params match {
      case List(softwareName, softwareVersion)
        => lookupAvailableMarts(species)
            .right.flatMap { case marts =>
              marts
              .get(s"${softwareName}_mart_${softwareVersion}")
              .toRight(s"No good serverVirtualSchema for ${species}, available: ${marts.mkString(", ")}")
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
def validateEnsemblPropertiesInOurConfigCorrespondToBioMartAttributes(species: String) = {
  lookupAttributes(species)
  .right.map {
    _
    .map{_.propertyName}
    .toSet
  }.right.flatMap { case bioMartAttributes =>
    (Annsrcs.allEnsemblGeneProperties(species) -- bioMartAttributes.toSet).toList match {
      case List()
        => Right(())
      case x
        => Left(s"Properties in our config for species ${species} not found as BioMart attributes: ${x.mkString(", ")}")
    }
  }
}






//ensembl_gene_id	Ensembl Gene ID	Ensembl Stable ID of the Gene	feature_page	html,txt,csv,tsv,xls	btaurus_gene_ensembl__gene__main	stable_id_1023

//Set("feature_page", "sequences", "snp", "structure", "homologs", "snp_somatic")

//    curl -s -X GET "${url}type=attributes&dataset=${datasetName}" | awk '{print $1}' | sort | uniq > ${f}.ensemblproperties

/*
serverVirtualSchema you need to look up
the other ones are properties
url is not quite an url, just like, "ensembl"

*/

def fetchProperties(url: String, serverVirtualSchema: String, datasetName: String, ensemblBioentityType: String, ensemblProperty: String, chromosomeName: String) = ""
