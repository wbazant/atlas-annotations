import $file.Combinators
import $file.BioMart
import $file.Retrieve
import scala.util.Random

import $file.property.AtlasProperty
import AtlasProperty._

val (atlasBioentityProperty, ensemblProperties)= (new AtlasBioentityProperty("bos_tauris", GENE, "interproterm"),List("interpro_description"))


def testTasks()= {
  Combinators.speciesList()
  .flatMap{case species =>
    Random.shuffle(Retrieve.retrieveAnnotationTasksForSpecies(species).flatten).headOption
  }
}

def out = testTasks().map{ case task =>
  (task, BioMart.fetchFromBioMart(task.species, task.filters, task.attributes))
}

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
