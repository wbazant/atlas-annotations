import ammonite.ops._
val ATLAS_PROD = pwd / up / up / "atlasprod"
val OUT = pwd / up /  "out"
val LOG = pwd / up /  "log"



val annsrcsPath = ATLAS_PROD/"bioentity_annotations"/"ensembl"/"annsrcs"
val wbpsAnnsrcsPath = ATLAS_PROD/"bioentity_annotations"/"wbps"/"annsrcs"

def annotationSources: Seq[Path] =
  ((ls! wbpsAnnsrcsPath) ++ (ls! annsrcsPath))
  .filter{ case path =>
    path.isFile && path.segments.last.matches("[a-z]+_[a-z]+")
  }
  
def scriptOutDestination(fileName: String) = OUT/ fileName
