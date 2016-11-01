import $file.OracleUcp

import $ivy.`org.scalikejdbc::scalikejdbc:2.4.2`
import scalikejdbc._

val ds = OracleUcp.getDataSource("jdbc:oracle:thin:@ora-vm-029.ebi.ac.uk:1531:ATLASDEV", "atlas3dev", "atlas3dev")

//Class.forName("oracle.jdbc.OracleDriver")
ConnectionPool.singleton(new DataSourceConnectionPool(ds))
implicit val session = AutoSession
