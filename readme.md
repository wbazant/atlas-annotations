# Quick start

Run Ammonite REPL:
`amm`

Connect to Oracle database, load Atlas classes and set up some objects:
```
import $file.AtlasDemo
```

Use Atlas classes to do interesting stuff:
```
AtlasDemo.analyticsSearchService.getBioentityIdentifiersForSpecies(AtlasDemo.human)

```

Alternatively, if you want to use ScalikeJDBC:
```
import $file.init.ScalikeJdbc
import ScalikeJdbc._
```

And you’re ready to go:
```
val experiments: List[Map[String,Any]] = sql"select * from experiment".map(_.toMap).list.apply() 
```

