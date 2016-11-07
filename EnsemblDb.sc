import $ivy.`org.scalikejdbc::scalikejdbc:2.4.2`
interp.load.cp(ammonite.ops.pwd/"lib"/"mysql-connector-java-5.1.40-bin.jar")
import scalikejdbc._

import scala.util.{Try, Success, Failure}
import $file.Annsrcs
import $file.Combinators

Class.forName("com.mysql.jdbc.Driver")

//note Annsrcs only handles mappings from one place, but Maria just added some mirror code in wbps.
//skip the forked code for now, but you'll have to come back to it later. Password and username there are ("", "ensro")
def registerConnection(mySqlDbName:String, url:String, user:String="anonymous", password:String="") = {
  ConnectionPool.add(mySqlDbName, url, user, password)
}

def getDatabase(mySqlDbName:String,version:String = "%") = {
  val nameWeExpect = mySqlDbName+"\\_core\\_"+version+"\\_%"
  Try(
    NamedDB(mySqlDbName) readOnly { implicit session =>
      sql"show databases like ${nameWeExpect}"
      .map(rs=> rs.toMap.values.map(_.toString))
      .list.apply()
      .flatten.sorted.reverse
    }
  ) match {
      case Success(ds)
       => ds.headOption.toRight(s"Could not find database: ${nameWeExpect}")
      case Failure(e)
        => Left(e.toString)
  }
}

def setupForSpecies(species: String) :Either[String,Unit]  = {
  Annsrcs.getValues(species, List("mySqlDbName", "mySqlDbUrl","software.version"))
  .right.map {
    case params => params match {
      case List(mySqlDbName, mySqlDbUrl, softwareVersion)
        => {
          registerConnection(mySqlDbName, s"jdbc:mysql://${mySqlDbUrl}/")
          
          getDatabase(mySqlDbName,softwareVersion)
          .right.map{case x =>()}
        }
      case x
        => Left(s"Unexpected: ${x}")
    }
  }.joinRight
}

def setupAll() = {
  Combinators.doAll(setupForSpecies)(Combinators.speciesList())
}
