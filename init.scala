//you can quickly install Oracle drivers through these magic imports
//import $ivy.`com.oracle:ojdbc6:11.2.0.3`
//import $ivy.`com.oracle:ucp:11.2.0.3`

import ammonite.ops._
import ammonite.ops.ImplicitWd._
interp.load.cp(ammonite.ops.pwd/"lib")
ls! pwd/'lib |! interp.load.cp //load all the jars

// set up the database
val ds = oracle.ucp.jdbc.PoolDataSourceFactory.getPoolDataSource()
ds.setURL("jdbc:oracle:thin:@ora-vm-029.ebi.ac.uk:1531:ATLASDEV")
ds.setUser("atlas3dev")
ds.setPassword("atlas3dev")
ds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource")
ds.setInitialPoolSize(1)
ds.setMaxPoolSize(1)
ds.setMaxIdleTime(1)
val jdbcTemplate = new org.springframework.jdbc.core.JdbcTemplate(ds)

// use objects modelling our problem domain
val human = new uk.ac.ebi.atlas.trader.SpeciesFactory(jdbcTemplate).getSpecies("homo sapiens")

//solr setup is much less fiddly - the client/query part is just a wrapper around a URL
val analyticsSolrClient = new org.apache.solr.client.solrj.impl.HttpSolrClient("http://localhost:8983/solr/analytics")

val analyticsSearchService = new uk.ac.ebi.atlas.search.analyticsindex.AnalyticsSearchService(new uk.ac.ebi.atlas.search.analyticsindex.AnalyticsIndexSearchDAO(new uk.ac.ebi.atlas.search.analyticsindex.solr.AnalyticsClient(analyticsSolrClient)))

//use high level features of Atlas
analyticsSearchService.getBioentityIdentifiersForSpecies(human)
