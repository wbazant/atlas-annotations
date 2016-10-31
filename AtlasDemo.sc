import $file.init.Oracle
import $file.init.Atlas

val jdbcTemplate = new org.springframework.jdbc.core.JdbcTemplate(Oracle.ds)
val namedParameterJdbcTemplate = new org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate(Oracle.ds)

// Use objects modelling our problem domain
val speciesFactory = new uk.ac.ebi.atlas.trader.SpeciesFactory(jdbcTemplate) 
val human = speciesFactory.create("homo sapiens")

// Solr setup is much less fiddly - the client/query part is just a wrapper around a URL
val analyticsSolrClient = new org.apache.solr.client.solrj.impl.HttpSolrClient("http://lime:8983/solr/analytics")
val analyticsSearchService = 
  new uk.ac.ebi.atlas.search.analyticsindex.AnalyticsSearchService(
    new uk.ac.ebi.atlas.search.analyticsindex.AnalyticsIndexSearchDAO(
        new uk.ac.ebi.atlas.search.analyticsindex.solr.AnalyticsClient(analyticsSolrClient)))
