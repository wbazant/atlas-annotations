/*
Input: location of the interpro file downloaded from their FTP site
we extract from such lines only: <interpro id="IPR000003" protein_count="1309" short_name="Retinoid-X_rcpt/HNF4" type="Family">
Stdout: <interpro_name><tab><interpro id><tab><interpro description>
*/
import scala.io.Source
import scala.xml.pull._

sealed trait ParseContext {
  def accumulatedOutput: List[String]
}
case class OutsideRelevantTasks(accumulatedOutput: List[String]) extends ParseContext
case class PassedInterproTag(accumulatedOutput: List[String], attributes: scala.xml.MetaData) extends ParseContext
case class PassedInterproAndNameTag(accumulatedOutput: List[String], attributes: scala.xml.MetaData) extends ParseContext

def parseStep(ctx: ParseContext,evt: XMLEvent) = {
  (evt,ctx) match {
    case (EvElemStart(_, "interpro", attributes,_), context)
      => PassedInterproTag(context.accumulatedOutput, attributes)
    case (EvElemStart(_, "name", _, _), PassedInterproTag(accumulatedOutput, attributes))
      => PassedInterproAndNameTag(accumulatedOutput, attributes)
    case (EvText(t), PassedInterproAndNameTag(accumulatedOutput, attributes))
      => OutsideRelevantTasks(s"${t}\t${attributeFromMetaData("id", attributes)}\t${attributeFromMetaData("type",attributes)}" :: accumulatedOutput)
    case (_, context)
      => context
  }
}

def attributeFromMetaData(attr: String, metaData: scala.xml.MetaData) = {
  metaData.get(attr).map(_.text).getOrElse("")
}

def parse(fileLocation: String) = {
  new XMLEventReader(Source.fromFile(fileLocation))
  .foldLeft(OutsideRelevantTasks(List()): ParseContext)(parseStep)
  .accumulatedOutput
  .reverse
}

def main(fileLocation: String) = {
  parse(fileLocation)
  .foreach(println(_))
}
