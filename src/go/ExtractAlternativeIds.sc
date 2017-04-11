/*
Input: location of go.owl downloaded from http://geneontology.org/ontology/go.owl
<owl:Class>
    <oboInOwl:hasAlternativeId>GO:0019952</oboInOwl:hasAlternativeId>
    <oboInOwl:hasAlternativeId>GO:0050876</oboInOwl:hasAlternativeId>
    <oboInOwl:id>GO:0000003</oboInOwl:id>
</owl:Class>
will extract:
GO:0019952\tGO:0000003
GO:0050876\tGO:0000003

Stdout: <alternative_id><tab><canonical_id>
Used when fetching ids: pipeline/retrieve/Transform.sc
*/
import scala.io.Source
import scala.xml.pull._

type Result = (String, String)
case class OwlClassResult(maybeId: Option[String] = None, alternativeIds: List[String] = List()) {
  def noteId(id: String) = OwlClassResult(Some(id), alternativeIds)
  def noteAlternativeId(alternativeId: String) = OwlClassResult(maybeId, alternativeId :: alternativeIds)
  def toList : List[Result] = maybeId.map{ case id => alternativeIds.map{case alternativeId => (alternativeId, id)}}.toList.flatten
}

sealed trait ReadingNodeText
case object ReadingId extends ReadingNodeText
case object ReadingAlternativeId extends ReadingNodeText
case object NotReadingNodeText extends ReadingNodeText


type X = (OwlClassResult,ReadingNodeText, List[Result])
val xInit : X = (OwlClassResult(), NotReadingNodeText, List[(String,String)]())
def parseStep(x: X, evt: XMLEvent) : X = {
  val (currentOwlClass, isReadingNodeText, acc) = x
  (evt, isReadingNodeText) match {
    case (EvElemStart("oboInOwl", "hasAlternativeId", _, _), _)
      => (currentOwlClass,ReadingAlternativeId, acc)
    case (EvElemStart("oboInOwl", "id", _, _), _)
      => (currentOwlClass,ReadingId, acc)
    case (EvText(t), ReadingAlternativeId)
      => (currentOwlClass.noteAlternativeId(t),NotReadingNodeText, acc)
    case (EvText(t), ReadingId)
      => (currentOwlClass.noteId(t), NotReadingNodeText, acc)
    case (EvElemEnd("owl", "Class"), _)
      => (OwlClassResult(), NotReadingNodeText, currentOwlClass.toList ::: acc )
    case _
      => x
  }
}


def parse(fileLocation: String) = {
  new XMLEventReader(Source.fromFile(fileLocation))
  .foldLeft(xInit)(parseStep)
  ._3
  .reverse
}

def main(fileLocation: String) = {
  parse(fileLocation)
  .foreach{
    case (alternativeId, id)
      => println(s"${alternativeId}\t${id}")
  }
}
