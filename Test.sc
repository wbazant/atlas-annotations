import $file.src.Combinators
import $file.src.BioMart
import $file.src.Tasks
import scala.util.Random

import $file.src.property.AtlasProperty
import AtlasProperty._

val (atlasBioentityProperty, ensemblProperties)= (new AtlasBioentityProperty("bos_taurus", GENE, "interproterm"),List("interpro_description"))


def testTasks()= {
  Combinators.speciesList()
  .flatMap{case species =>
    Random.shuffle(Tasks.retrieveAnnotationTasksForSpecies(species).flatten).headOption
  }
}

def out = testTasks().map{ case task =>
  (task, BioMart.fetchFromBioMart(task.species, task.filters, task.attributes))
}

import $file.src.BioMart
BioMart.fetchFromBioMart("bos_taurus", Map(), List("ensembl_gene_id", "interpro_description"))
/*
{
  Combinators.speciesList()
  .flatMap{case species =>
    Retrieve.retrieveAnnotationTasksForSpecies(species).flatten.headOption
  }
  .map{ case task =>
    (task, BioMart.fetchFromBioMart(task.species, task.filters, task.attributes))
  }
  .map{case(task, e) => val z = e match {case Right(x) => x.split("\n").size.toString case Left(e) => e}; (task,z)}
}
*/
