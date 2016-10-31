
//the DSL way
case class GeneDescription(geneName: String, value: Option[String])
object GeneDescription extends SQLSyntaxSupport[GeneDescription] {
  override val tableName = "gene"
  override val columns = Seq("stable_id", "description")

  def apply(rn: ResultName[GeneDescription],rs: WrappedResultSet) =
    new GeneDescription(rs.get(rn.field("stable_id")), rs.get(rn.field("description")))
}

//within right method
val d = GeneDescription.syntax("d")
SQL("use bos_taurus_core_86_31;").execute.apply()
withSQL {select.from(GeneDescription as d)}.map(rs=>GeneDescription(d.resultName,rs)).list.apply()


//the SQL way
SQL("use bos_taurus_core_86_31;").execute.apply()
sql"""
     SELECT DISTINCT gene.stable_id, external_synonym.synonym
     FROM gene, xref, external_synonym
     WHERE gene.display_xref_id = xref.xref_id AND external_synonym.xref_id = xref.xref_id
     ORDER BY gene.stable_id
    """.map(_.toMap).list.apply()
