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

  def configurationXml =
    ls(path)
    .collectFirst {
      case p if p.name == accession+"-configuration.xml"
       => XML.loadFile(p.toNIO.toFile)
     }

  def arrayDesign = configurationXml.map(_ \\ "array_design").map(_.text.trim).filter(!_.isEmpty)
}



lazy val all = Directories.ANALYSIS_EXPERIMENTS.map(ExperimentDirectory(_))

def allArrayDesigns =
  ANALYSIS_EXPERIMENTS
  .map(ExperimentDirectory(_))
  .groupBy(_.arrayDesign)
  .toList
  .collect {
    case (Some(arrayDesign), experiments)
      => (arrayDesign, experiments.map(_.accession))
  }
