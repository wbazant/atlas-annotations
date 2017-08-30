/*
Input: location of go.owl or po.owl downloaded from http://geneontology.org/ontology/go.owl
<owl:Class>
    <rdfs:label>embryo proper</rdfs:label>
    <oboInOwl:hasAlternativeId>GO:0019952</oboInOwl:hasAlternativeId>
    <oboInOwl:hasAlternativeId>GO:0050876</oboInOwl:hasAlternativeId>
    <oboInOwl:id>GO:0000003</oboInOwl:id>
</owl:Class>

//alternativeIds output
GO:0019952\tGO:0000003
GO:0050876\tGO:0000003

//terms output
GO:0000003\tembryo proper
*/
import scala.io.Source
import scala.xml.pull._

type Result = (String, String)
case class OwlClassResult(maybeId: Option[String] = None, properties: List[String] = List(), skippingTag: Option[String] = None) {
  def noteId(id: String) = OwlClassResult(Some(id), properties, skippingTag)
  def noteProperty(property: String) = OwlClassResult(maybeId, property :: properties, skippingTag)
  def toList : List[Result] = maybeId.map{ case id => properties.map{case property => (id,property)}}.toList.flatten
}

sealed trait ReadingNodeText
case object ReadingId extends ReadingNodeText
case object ReadingProperty extends ReadingNodeText
case object NotReadingNodeText extends ReadingNodeText



type X = (Option[String], Option[OwlClassResult],ReadingNodeText, List[Result])
val xInit : X = (None, None, NotReadingNodeText, List[(String,String)]())
def parseStep(propertyNamespace: String, property:String)(x: X, evt: XMLEvent) : X = {
  val (skipping, currentOwlClass, isReadingNodeText, acc) = x
  (skipping, evt,currentOwlClass, isReadingNodeText) match {
    case (None, EvElemStart("owl", "Class", _, _),None, _)
      => (None, Some(OwlClassResult()), NotReadingNodeText, acc )
    case (None, EvElemStart("owl", owlElement, _, _),Some(owl), _)
      => (Some(owlElement), currentOwlClass, isReadingNodeText, acc)
    case (Some(owlElementSkipping), EvElemEnd("owl", owlElement), _, _ ) if owlElement == owlElementSkipping
      => (None, currentOwlClass, isReadingNodeText, acc)
    case (None, EvElemStart(pns, p, _, _),Some(owl), _) if pns == propertyNamespace && p == property
      => (None, currentOwlClass,ReadingProperty, acc)
    case (None, EvElemStart("oboInOwl", "id", _, _),Some(owl), _)
      => (None, currentOwlClass,ReadingId, acc)
    case (None, EvText(t), Some(owl), ReadingProperty)
      => (None, Some(owl.noteProperty(t)),NotReadingNodeText, acc)
    case (None, EvText(t), Some(owl), ReadingId)
      => (None, Some(owl.noteId(t)), NotReadingNodeText, acc)
    case (None, EvElemEnd("owl", "Class"),Some(owl), _)
      => (None,None, NotReadingNodeText, owl.toList ::: acc )
    case _
      => x
  }
}

def parse(propertyNamespace: String, property:String)(fileLocation: ammonite.ops.Path) = {
  new XMLEventReader(Source.fromFile(fileLocation.toIO))
  .foldLeft(xInit)(parseStep(propertyNamespace, property))
  ._4
  .reverse
}

@main
def main(what: String, fileLocation: ammonite.ops.Path) = {
    what match {
        case "terms"
            => terms(fileLocation)
        case "alternativeIds"
            => alternativeIds(fileLocation)
        case _
            => System.err.println("Usage: <terms or alternativeIds> <fileLocation>")
    }
}

def terms(fileLocation: ammonite.ops.Path) = {
  parse("rdfs", "label")(fileLocation)
  .foreach{
    case (id, goTermText)
      => println(s"${id}\t${goTermText}")
  }
}

def alternativeIds(fileLocation: ammonite.ops.Path) = {
  parse("oboInOwl", "hasAlternativeId")(fileLocation)
  .map(_.swap)
  .foreach{
    case (alternativeId, id)
      => println(s"${alternativeId}\t${id}")
  }
}
