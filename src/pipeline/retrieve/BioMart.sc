interp.load.ivy("org.scalaj" %% "scalaj-http" % "2.3.0")
import scalaj.http._
import scala.xml.XML
import scala.util.{Try, Success, Failure}

import $file.^.^.util.Combinators
import $file.^.^.property.AnnotationSource
import AnnotationSource.AnnotationSource
import $file.^.^.property.AtlasProperty

def request(databaseName: String,properties: Map[String, String]) : HttpRequest = {
  val base = databaseName match {
    case "metazoa" => "http://metazoa.ensembl.org"
    case "plants" => "http://plants.ensembl.org"
    case "fungi" => "http://fungi.ensembl.org"
    case "parasite" => "http://parasite.wormbase.org"
    case _ => "http://www.ensembl.org"
  }
  Http(base+"/biomart/martservice").params(properties).timeout(connTimeoutMs = 5000, readTimeoutMs = 1000000)
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

def registryRequest(annotationSource: AnnotationSource) = {
  AnnotationSource.getValue(annotationSource, "databaseName")
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

def lookupAvailableMartsAndTheirSchemas(annotationSource: AnnotationSource) : Either[String, Map[String, String]] = {
  registryRequest(annotationSource)
  .right.map {
    case (req)
      => getAsXml(req)
  }.joinRight
  .right.map {
    case xml
      => availableMartsAndTheirSchemas(xml)
  }
}

def pickMostAppropriateMart(expectedMart: String)(marts: Map[String, String]) : Either[String, String] = {
  val expected = marts.get(expectedMart)
  val fallback = marts.filter(_._1.contains(expectedMart)).values.headOption
  expected
  .orElse(fallback)
  .toRight(s"Could not determine serverVirtualSchema because expected mart ${expectedMart} not found, available marts: ${marts.mkString(", ")}")
}

//TODO this is a very annoying way of finding out you're not using up to date versions of Ensembl Plants
def lookupServerVirtualSchema(annotationSource: AnnotationSource) :Either[String,String]  = {
  AnnotationSource.getValues(annotationSource, List("software.name", "software.version"))
  .right.map {
    case params => params match {
      case List(softwareName, softwareVersion)
        => {
            lookupAvailableMartsAndTheirSchemas(annotationSource)
              .right.flatMap(pickMostAppropriateMart(s"${softwareName}_mart_${softwareVersion}"))
          }
      case x
        => Left(s"Unexpected: ${x}")
    }
  }.joinRight
}

def attributesRequest(annotationSource:AnnotationSource) = {
  AnnotationSource.getValues(annotationSource, List("databaseName", "datasetName"))
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
Right(Attribute("ensembl_gene_id", "Ensembl Gene ID/ Ensembl Stable ID of the Gene", "feature_page", "btaurus_gene_ensembl__gene__main", "stable_id_1023"))
*/
def lookupAttributes(annotationSource:AnnotationSource) = {
  attributesRequest(annotationSource)
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

case class BiomartAuxiliaryInfo(
  databaseName: String,
  serverVirtualSchema: String,
  datasetName: String,
  datasetFilters: Map[String, String] = Map())

object BiomartAuxiliaryInfo {
  def getMap(annotationSourceKeys: Seq[AnnotationSource]) = {
    Combinators.combine(
      annotationSourceKeys
      .map{ case annotationSource : AnnotationSource =>
        getForAnnotationSource(annotationSource)
        .right.map((annotationSource, _))
      }
    )
    .right.map(_.toMap)
  }

  private def datasetFiltersForAnnotationSource(annotationSource: AnnotationSource) = {
    ( AnnotationSource.getOptionalValue(annotationSource, "datasetFilterName"),
      AnnotationSource.getOptionalValue(annotationSource, "datasetFilterValue")
    ) match {
      case (Some(datasetFilterName), Some(datasetFilterValue))
        => Right(Map(datasetFilterName -> datasetFilterValue))
      case (None,None)
        => Right(Map[String,String]())
      case _
        => Left("Bad dataset filters for annotation source ${annotationSource}")
    }
  }

  def getForAnnotationSource(annotationSource: AnnotationSource) = {
    ( AnnotationSource.getValue(annotationSource, "databaseName"),
      lookupServerVirtualSchema(annotationSource),
      AnnotationSource.getValue(annotationSource, "datasetName"),
      datasetFiltersForAnnotationSource(annotationSource)
    ) match {
      case (
          Right(databaseName),
          Right(serverVirtualSchema),
          Right(datasetName),
          Right(datasetFilters)
        )
        => Right(BiomartAuxiliaryInfo(databaseName, serverVirtualSchema, datasetName, datasetFilters))
      case xs
        => Left("Can not create BiomartAuxiliaryInfo: "+ xs.productIterator.mkString(", "))
    }
  }
}

def queryParameter(
  biomartAuxiliaryInfo : BiomartAuxiliaryInfo,
  filters: Map[String, String],
  attributes: List[String]) = {
  <Query
    virtualSchemaName={biomartAuxiliaryInfo.serverVirtualSchema}
    formatter="TSV"
    header="0"
    uniqueRows="1"
    count="0">
    <Dataset
      name={biomartAuxiliaryInfo.datasetName}
      interface="default">
      {(biomartAuxiliaryInfo.datasetFilters ++ filters)
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
}

def bioMartRequest(
  biomartAuxiliaryInfo : BiomartAuxiliaryInfo,
  filters: Map[String, String],
  attributes: List[String]) = {
    val query = queryParameter(biomartAuxiliaryInfo, filters, attributes)

    request(biomartAuxiliaryInfo.databaseName, Map(("query",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE Query>"+ query.toString)
    )
  )
}

def fetchFromBioMart(aux:Map[AnnotationSource, BiomartAuxiliaryInfo])(annotationSource: AnnotationSource, filters: Map[String, String], attributes: List[String]) : Either[String, Array[String]]= {
  aux.get(annotationSource).map(Right(_))
  .getOrElse(BiomartAuxiliaryInfo.getForAnnotationSource(annotationSource))
  .right.map{ case bioMartAuxiliaryInfo =>
    bioMartRequest(bioMartAuxiliaryInfo, filters, attributes)
  }
  .right.flatMap { case request =>
    request.asString.body match {
      case ""
        => Left("Received response with an empty body for: "+request.toString)
      case x
        => Right(x.split('\n'))
    }
  }
}

def fetchFromBioMart(annotationSource: AnnotationSource, filters: Map[String, String], attributes: List[String]) : Either[String, Array[String]] = {
  fetchFromBioMart(Map[AnnotationSource, BiomartAuxiliaryInfo]())(annotationSource, filters, attributes)
}
