import $file.OracleUcp

import $ivy.`org.scalikejdbc::scalikejdbc:2.4.2`

import scalikejdbc._
import scala.util.parsing.json._
import ammonite.ops._
import ammonite.ops.ImplicitWd._

val json = JSON.parseFull(read! pwd/"oracle-settings.json")

val (url, user, password) = 
  List("url", "user", "password").map(
    e => json.get.asInstanceOf[Map[String, Any]](e).asInstanceOf[String]
  ) match {
      case List(a, b, c) => (a, b, c) 
    }

val ds = OracleUcp.getDataSource(url, user, password)

//Class.forName("oracle.jdbc.OracleDriver")
ConnectionPool.singleton(new DataSourceConnectionPool(ds))
implicit val session = AutoSession
