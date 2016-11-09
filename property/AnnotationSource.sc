import ammonite.ops._

val annsrcsPath: Path = pwd/up/"atlasprod"/"bioentity_annotations"/"ensembl"/"annsrcs"


case class Property(species: String, name: String, value: String){
  def isAboutArrayDesign = name.contains("arrayDesign")
}

def readProperties(annsrcsPath: Path) = {
  ls(annsrcsPath).map {
    case f => {
      read.lines(f)
      .map {
        line => {
          (f.name, line.split("=").toList.headOption.getOrElse(""), line.split("=").toList.lastOption.getOrElse(""))
        }
      }
      .filter {
        _ match {
          case (_, _, "") => false
          case (_, "", _) => false
          case _ => true
        }
      }
    }
  }
  .flatten
  .map {
    case (x,y,z) => Property(x,y,z)
  }
}

val properties = readProperties(annsrcsPath)

def getValue(species: String, propertyName: String) : Either[String, String] = {
  properties
  .filter {
    case p =>
      p.species == species && p.name == propertyName
  }
  .headOption
  .map{_.value} match {
    case Some(result)
      => Right(result)
    case None
      => Left(s"Property ${propertyName} missing for species ${species}")
  }
}

def getValues[T<:Seq[String]](species: String, propertyNames: T)= {
  val m = properties
  .filter {
    case p =>
      p.species == species && propertyNames.contains(p.name)
  }
  .map {
    case p
      => (p.name, p.value)
  }
  .toMap
  if(m.keySet == propertyNames.toSet){
    Right(propertyNames.map{m.get(_).get})
  } else {
    Left(s"Properties ${(propertyNames.toSet -- m.keySet).mkString(", ")} missing for species ${species}")
  }
}
