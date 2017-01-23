/*
Input: location of the interpro file downloaded from their FTP site
we extract from such lines only: <interpro id="IPR000003" protein_count="1309" short_name="Retinoid-X_rcpt/HNF4" type="Family">
Stdout: <interpro_name><tab><interpro id><tab><interpro description>
*/
import scala.io.Source
import scala.xml.pull._

def lineFromMetadata(attributes: scala.xml.MetaData) = {
  List("short_name", "id", "type")
  .map {
    case attr
      => attributes.get(attr).map(_.text).getOrElse("")
  }.mkString("\t")
}

def parse(fileLocation: String) = {
  new XMLEventReader(Source.fromFile(fileLocation))
  .collect {
    case EvElemStart(_, "interpro", attributes, _)
      => lineFromMetadata(attributes)
  }
}

def main(fileLocation: String) = {
  parse(fileLocation)
  .foreach(println(_))
}
