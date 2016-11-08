import $file.Annsrcs
import $file.Combinators


case class RetrieveAnnotationTask(species: String, filters: Map[String, String], attributes: List[String])


def retrieveAnnotationTasksForSpecies(species: String): List[List[RetrieveAnnotationTask]] = {
  val ensemblBioentityTypes = Map(
    "ensgene"->"ensembl_gene_id",
    "ensprotein"->"ensembl_peptide_id",
    "enstranscript"-> "ensembl_transcript_id")

  val pairs =
    ensemblBioentityTypes.values.flatMap{case bioentityType =>
      Annsrcs.allEnsemblBioentityProperties(species)
      .map{case bioentityProperty =>
        (bioentityType, bioentityProperty)
      }
    }
    .filter{case (bioentityType, propertyName) =>
      bioentityType != propertyName
    }
    .toList

  val shards =
    Annsrcs.getValue(species,"chromosomeName")
    .right.map(_.split(",").toList.map(Map("chromosome_name"->_)))
    left.map{missingChromosome => Map[String,String]()}
    .merge

  val retrieveEnsemblPropertiesTasks =
    pairs.map {case (bioentityType, propertyName) =>
      shards.map {case shard =>
        RetrieveAnnotationTask(species, shard, List(bioentityType, propertyName))
      }
    }

  val retrieveArrayDesignsTasks =
    Annsrcs.allEnsemblArrayDesigns(species)
    .map(("ensembl_gene_id", _))
    .map {case (bioentityType, propertyName) =>
      shards.map {case shard =>
        RetrieveAnnotationTask(species, shard, List(bioentityType, propertyName))
      }
    }
}

def retrieveAnnotationTasks() = {
  Combinators.speciesList()
  .map(retrieveAnnotationTasksForSpecies)
  .flatten
}
/*
def ensemblUpdates: Future[Nothing] = {
  //s
}



trait OperatesOnFiles {
  def filesBefore: List[Path]
  def target: Path
  def filesConsumed: List[Path]

  def isDone: Boolean = {
    filesBefore()
    .filter{filesConsumed().contains(_)}
    .map{_.exists()}
    .foldRight(target().exists)(_||_)
  }

  def canStart: Boolean = {
    filesBefore()
    .map{_.exists()}
    .foldRight(true)(_||_)
  }
}

*/
