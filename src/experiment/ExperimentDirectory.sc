import $file.^.Directories
import Directories.ANALYSIS_EXPERIMENTS
import ammonite.ops._
import scala.xml.XML

/*
What we need:
(genenames, gsea)
Analytics tsv:
../E-MTAB-1625/E-MTAB-1625-analytics.tsv
made by IRAP. If not there, the experiment's not ready - the experiment processing has failed.

*/

case class ExperimentDirectory(path: Path) {

  def accession = path.name

  def configurationXml = XML.loadFile((path / (accession+"-configuration.xml")).toNIO.toFile)

  def arrayDesigns = {
    if(path.segments.contains("microarray")) {
      (configurationXml \\ "array_design")
      .map(_.text.trim)
    } else {
      List()
    }
  }
}



lazy val all = Directories.ANALYSIS_EXPERIMENTS.map(ExperimentDirectory(_))

def allArrayDesigns =
  ANALYSIS_EXPERIMENTS
  .map(ExperimentDirectory(_))
  .groupBy(_.arrayDesigns)
  .collect {
    case (arrayDesigns, experiments) if ! arrayDesigns.isEmpty
      => (arrayDesigns, experiments.map(_.accession))
  }
