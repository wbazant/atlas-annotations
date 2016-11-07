import $ivy.`org.scalikejdbc::scalikejdbc:2.4.2`
interp.load.cp(ammonite.ops.pwd/"lib"/"mysql-connector-java-5.1.40-bin.jar")
import scalikejdbc._


Class.forName("com.mysql.jdbc.Driver")
ConnectionPool.singleton("jdbc:mysql://ensembldb.ensembl.org:5306/", "anonymous", "")
implicit val session = AutoSession

sql"show databases like 'aedes_aegypti_core_55_1d'".map(rs=> rs.toMap.values.map(_.toString)).list.apply().flatten.sorted
sql"select * from information_schema.columns where table_schema = 'aedes_aegypti_core_55_1d' and table_name = 'gene'".map(_.toMap.get("COLUMN_NAME")).list.apply()


def databasesForDbName(mySqlDbName: String,version:String = "%")(implicit session: DBSession) =
  sql"show databases like ${mySqlDbName+"\\_core\\_"+version+"\\_%"}"
  .map(rs=> rs.toMap.values.map(_.toString))
  .list.apply()
  .flatten.sorted.reverse
def databaseForSpecies(species:String,version:String = "%") = databasesForDbName(species.toLowerCase.replace(" ","_"),version).head

def geneSynonyms(database: String) = {
  def get(m: Map[String,Any],c:String) = m.get(c).map(_.toString).getOrElse("")

  sql"""
  use ${database};
   SELECT DISTINCT gene.stable_id, external_synonym.synonym
   FROM gene, xref, external_synonym
   WHERE gene.display_xref_id = xref.xref_id AND external_synonym.xref_id = xref.xref_id
   ORDER BY gene.stable_id
  """.map(_.toMap).list.apply().map(_extract)
}



//runs into interpreter problems :$
implicit val session = AutoSession
def retrieveProperties(schema: String, table: =>String, idField: String, propertyField: String) = {
  class Dao(val geneName: String, val value: Option[String])
  object Dao extends SQLSyntaxSupport[Dao] {
    override def schemaName = Some(schema)
    override def tableName = table
    override def columns = Seq(idField, propertyField)

    override def tableNameWithSchema = schemaName.map { schema => s"${schema}.${tableName}" }.getOrElse(tableName)

    def apply(rn: ResultName[Dao],rs: WrappedResultSet) =
      new Dao(rs.get(rn.field(idField)), rs.get(rn.field(propertyField)))
  }
  Dao.tableNameWithSchema
    val d = Dao.syntax

     withSQL {
       select.from(Dao as d)
     }
     .map(rs=>Dao(d.resultName, rs))
     .list
     .apply()
     .map{dao=> (dao.geneName,dao.value.getOrElse(""))}
}



case class Dao(geneName: String, value: Option[String])
object Dao extends SQLSyntaxSupport[Dao] {
  //override val schemaName = Some("danio_rerio_core_86_10")
  override val tableName = "gene"
  override val columns = Seq("stable_id", "description")

  def apply(rn: ResultName[Dao],rs: WrappedResultSet) =
    new Dao(rs.get(rn.field("stable_id")), rs.get(rn.field("description")))
}

val d = Dao.syntax("d")
withSQL {select.from(Dao as d)}.map(rs=>Dao(d.resultName,rs)).list.apply()

case class EnsemblColumn(schema: String, table: String, column: String)
def _extract(m:Map[String,Any]) = {
  def get(m: Map[String,Any],c:String) = m.get(c).map(_.toString).getOrElse("")
  new EnsemblColumn(get(m,"table_schema"),get(m,"table_name"),get(m,"column_name"))
}
def columnsForSpecies(species: String,kind:String = "core", version:String = "%") = sql"""
  select table_schema,table_name,column_name
  from information_schema.columns
  where table_schema like ${species.toLowerCase.replace(" ","_")+"\\_"+kind+"\\_"+version+"\\_%"}
  """.map(_.toMap).list.apply().map(_extract)

//schemasFor("bos_taurus","%", "86")("gene",Set("gene_id","description"))
//List("bos_taurus_otherfeatures_86_31", "bos_taurus_core_86_31")
def schemasFor(species: String,kind:String = "core", version: String = "%")(table: String, properties: Set[String]) = {
  columnsForSpecies(species,kind,version)
  .filter(_.table.equals(table))
  .groupBy(e=>(e.schema, e.table))
  .mapValues(_.map(_.column))
  .filter{
    case ((_schema,_table),_columns)=>
      (_table.equals("%") || _table.equals(table) )&& properties.subsetOf(_columns.toSet)
  }
  .keySet.map(_._1).toList.sorted.reverse
}
