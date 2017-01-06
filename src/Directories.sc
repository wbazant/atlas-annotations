import ammonite.ops._
val PROJECT_ROOT = pwd // because we will call Ammonite like that
val OUT = pwd / up /  "out" //TODO
val LOG = pwd / up /  "log" //TODO

if (!(PROJECT_ROOT/"annsrcs").toNIO.toFile.isDirectory){
  throw new RuntimeException("Annotations directory not found, possibly ammonite calls this from a wrong place: "+(PROJECT_ROOT/"annsrcs"))
}

val annsrcsPath = PROJECT_ROOT/"annsrcs"/"ensembl"
val wbpsAnnsrcsPath = PROJECT_ROOT/"annsrcs"/"wbps"

def annotationSources: Seq[Path] =
  ((ls! wbpsAnnsrcsPath) ++ (ls! annsrcsPath))
  .filter{ case path =>
    path.isFile && path.segments.last.matches("[a-z]+_[a-z]+")
  }

def scriptOutDestination(fileName: String) = OUT/ fileName
