//you can quickly install Oracle drivers through these magic imports
import $ivy.`com.oracle:ojdbc6:11.2.0.3`
import $ivy.`com.oracle:ucp:11.2.0.3`

val ds = oracle.ucp.jdbc.PoolDataSourceFactory.getPoolDataSource()
ds.setURL("jdbc:oracle:thin:@ora-vm-029.ebi.ac.uk:1531:ATLASDEV")
ds.setUser("atlas3dev")
ds.setPassword("atlas3dev")
ds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource")
ds.setInitialPoolSize(1)
ds.setMaxPoolSize(1)
ds.setMaxIdleTime(1)
