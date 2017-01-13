import ammonite.ops._
val PROJECT_ROOT = pwd // because we will call Ammonite like that

if (!(PROJECT_ROOT/"annsrcs").isDir){
  throw new RuntimeException("Annotations directory not found, possibly ammonite calls this from a wrong place: "+(PROJECT_ROOT/"annsrcs"))
}

lazy val ATLAS_PROD = Option(System.getenv.get("ATLAS_PROD")).map(Path(_)).filter(_.isDir) match {
  case Some(path)
    => path
  case None
    => {
      throw new RuntimeException("export $ATLAS_PROD as an environment variable")
      null
    }
}

lazy val alternativeToCanonicalGoTermMapping = {
  (read.lines!(ATLAS_PROD / "bioentity_properties" /"go" / "go.alternativeID2CanonicalID.tsv"))
  .flatMap{ case line =>
      line.split("\t").toList match {
        case List(mapping, mapped)
          => Some((mapping,mapped))
        case _
          => None
      }
  }.toMap
}

val annsrcsPath = PROJECT_ROOT/"annsrcs"/"ensembl"
val wbpsAnnsrcsPath = PROJECT_ROOT/"annsrcs"/"wbps"

def annotationSources: Seq[Path] =
  ((ls! wbpsAnnsrcsPath) ++ (ls! annsrcsPath))
  .filter{ case path =>
    path.isFile && path.segments.last.matches("[a-z]+_[a-z]+")
  }
