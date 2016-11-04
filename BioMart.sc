interp.load.ivy("org.scalaj" %% "scalaj-http" % "2.2.0")
import scalaj.http._
import scala.xml.XML
import scala.util.{Try, Success, Failure}

import $file.Annsrcs


def request(kingdom: String,properties: Map[String, String]) : HttpRequest = {
  val base = kingdom match {
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

def registryRequest(kingdom: String) = request(kingdom, Map("type"->"registry"))

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
  Annsrcs.getValue(species, "databaseName")
  .right.map {
    case (databaseName)
      => getAsXml(registryRequest(databaseName))
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

// def attributesRequest(species:String) = {
//   Annsrcs.getValue(species,"datasetName")
//   .right.map {
//     case datasetName
//       =>
//   }
// }
//    curl -s -X GET "${url}type=attributes&dataset=${datasetName}" | awk '{print $1}' | sort | uniq > ${f}.ensemblproperties

/*
serverVirtualSchema you need to look up
the other ones are properties
url is not quite an url, just like, "ensembl"

*/

def fetchProperties(url: String, serverVirtualSchema: String, datasetName: String, ensemblBioentityType: String, ensemblProperty: String, chromosomeName: String) = ""
