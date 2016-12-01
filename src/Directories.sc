import ammonite.ops._
val ATLAS_PROD = pwd / up /  "ATLAS_PROD_FAKE"
val OUT = pwd / up /  "out"


val annsrcsPath = ATLAS_PROD/"bioentity_annotations"/"ensembl"/"annsrcs"
val wbpsAnnsrcsPath = ATLAS_PROD/"bioentity_annotations"/"wbps"/"annsrcs"


def scriptOutDestination(fileName: String) = OUT/ fileName
