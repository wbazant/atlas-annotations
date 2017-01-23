/*
Input: location of the interpro file downloaded from their FTP site
we extract from such lines only: <interpro id="IPR000003" protein_count="1309" short_name="Retinoid-X_rcpt/HNF4" type="Family">
Stdout: <interpro_name><tab><interpro id><tab><interpro description>
*/
import scala.io.Source
import scala.xml.pull._

def attributeFromMetaData(attr: String, metaData: scala.xml.MetaData) = {
  metaData.get(attr).map(_.text).getOrElse("")
}

private def parseRecursively(xml: XMLEventReader, accTag: Option[scala.xml.MetaData],parsingName: Boolean, accOut: Stream[String]) : Stream[String] = {
  if(xml.hasNext) {
    xml.next match {
      case EvElemStart(_, "interpro", attributes, _)
        => parseRecursively(xml, Some(attributes), false, accOut)
      case EvElemStart(_, "name", attributes, _)
        => parseRecursively(xml, accTag, true, accOut)
      case EvText(t)
        => (accTag, parsingName) match {
          case (Some(metadata), true)
            => parseRecursively(xml, None, false,s"${t}\t${attributeFromMetaData("id", metadata)}\t${attributeFromMetaData("type",metadata)}" #:: accOut)
          case _
            => parseRecursively(xml, accTag, parsingName, accOut)
        }
      case _
        => parseRecursively(xml, accTag, parsingName, accOut)
    }
  } else {
    accOut
  }
}

def parse(fileLocation: String) = {
  parseRecursively(new XMLEventReader(Source.fromFile(fileLocation)), None, false, Stream.empty)
  .reverse
}

def main(fileLocation: String) = {
  parse(fileLocation)
  .foreach(println(_))
}
