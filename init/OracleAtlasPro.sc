import ammonite.ops._

//you can quickly install Oracle drivers through these magic imports
import $ivy.`com.oracle:ojdbc6:11.2.0.3`
import $ivy.`com.oracle:ucp:11.2.0.3`

val ds = oracle.ucp.jdbc.PoolDataSourceFactory.getPoolDataSource()
ds.setURL(read! pwd/up/"oracleServer")
ds.setUser(read! pwd/up/"user")
ds.setPassword(read! pwd/up/"pass")
ds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource")
ds.setInitialPoolSize(1)
ds.setMaxPoolSize(1)
ds.setMaxIdleTime(1)
