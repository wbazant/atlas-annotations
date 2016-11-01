import $ivy.`com.oracle:ojdbc6:11.2.0.3`
import $ivy.`com.oracle:ucp:11.2.0.3`

def getDataSource(url: String, user: String, password: String): oracle.ucp.jdbc.PoolDataSource = {
  val ds = oracle.ucp.jdbc.PoolDataSourceFactory.getPoolDataSource()
  ds.setURL(url)
  ds.setUser(user)
  ds.setPassword(password)
  ds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource")
  ds.setInitialPoolSize(1)
  ds.setMaxPoolSize(1)
  ds.setMaxIdleTime(1)
  ds
}
