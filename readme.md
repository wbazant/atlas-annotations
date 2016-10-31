# Quick start
Run ammonite:
`amm`

Load `init.scala`:
```
import ammonite.ops._
interp.load.module(Path(pwd + "/init.scala"))
```

Use Atlas classes to do interesting stuff:
```
analyticsSearchService.getBioentityIdentifiersForSpecies(human)

```
