import ammonite.ops._

val annsrcsPath: Path = pwd/up/"atlasprod"/"bioentity_annotations"/"ensembl"/"annsrcs"
val wbpsAnnsrcsPath: Path = pwd/up/"atlasprod"/"bioentity_annotations"/"wbps"/"annsrcs"

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
val wbpsProperties = readProperties(wbpsAnnsrcsPath)

def getValue(source: Seq[Property] = properties)(species: String, propertyName: String) : Either[String, String] = {
  source
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

def getValue(species: String, propertyName: String) : Either[String, String] = {
  if (wbpsProperties.exists(_.species == species)) getValue(wbpsProperties)(species, propertyName)
  else getValue()(species, propertyName)
}

def getValues[T<:Seq[String]](source: Seq[Property] = properties)(species: String, propertyNames: T) : Either[String, Seq[String]] = {
  val m = source
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

def getValues[T<:Seq[String]](species: String, propertyNames: T)  : Either[String, Seq[String]] = {
  if (wbpsProperties.exists(_.species == species)) getValues(wbpsProperties)(species, propertyNames)
  else getValues()(species, propertyNames)
}
