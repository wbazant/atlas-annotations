import ammonite.ops._
import $file.^.Directories
import Directories.annotationSources

type AnnotationSource = ammonite.ops.Path

case class Property(annotationSource: AnnotationSource, name: String, value: String){
  def isAboutArrayDesign = name.contains("arrayDesign")
}

object Property {
  def readFromAnnotationSource(annotationSource: AnnotationSource) : Seq[Property] = {
    read.lines(annotationSource)
    .map {
      line => {
        (line.split("=").toList.headOption.getOrElse(""), line.split("=").toList.lastOption.getOrElse(""))
      }
    }
    .filter {
      _ match {
        case (_, "") => false
        case ("", _) => false
        case _ => true
      }
    }
    .map {
      case (name,value) => Property(annotationSource, name, value)
    }
  }
}

lazy val properties = annotationSources.flatMap{Property.readFromAnnotationSource(_)}

def getValue(annotationSource: AnnotationSource, propertyName: String) : Either[String, String] = {
  properties
  .filter {
    case p =>
      p.annotationSource == annotationSource && p.name == propertyName
  }
  .headOption
  .map{_.value} match {
    case Some(result)
      => Right(result)
    case None
      => Left(s"Property ${propertyName} missing for annotation source ${annotationSource}")
  }
}

def getValues[T<:Seq[String]](annotationSource: AnnotationSource, propertyNames: T) : Either[String, Seq[String]] = {
  val m =
    properties
    .filter {
      case p =>
        p.annotationSource == annotationSource && propertyNames.contains(p.name)
    }
    .map {
      case p
        => (p.name, p.value)
    }
    .toMap
  if(m.keySet == propertyNames.toSet){
    Right(propertyNames.map{m.get(_).get})
  } else {
    Left(s"Properties ${(propertyNames.toSet -- m.keySet).mkString(", ")} missing for annotation source ${annotationSource.toString}")
  }
}
