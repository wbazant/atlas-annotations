import $file.Tasks
import $file.BioMart
import $file.property.Species
import Species.Species

import collection.mutable.{ HashMap, Set }

//private
def performBioMartTask(aux:Map[Species, BioMart.BiomartAuxiliaryInfo], task: Tasks.BioMartTask) : Either[String, String] = {

  val result = new HashMap[String, Set[String]]

  val t0 = System.nanoTime
  val errors = task.queries.flatMap { case (filters, attributes) =>
    BioMart.fetchFromBioMart(aux)(task.species, filters, attributes) match {
      case Right(res: Array[String])
        => res.flatMap{ case line =>
          if(line.filter(!Character.isWhitespace(_)).size == 0){
            //Filter out empty lines
            None
          }else if(line.map(_.isValidChar).reduce(_&&_)){
            val brokenLine = line.split("\t")

            result.put(brokenLine.head,
              result.get("x").getOrElse(Set())++=brokenLine.tail
            )
            None
          } else {
            Some(s"Result for ${task} contains invalid line: ${line}")
          }
        }
      case Left(err)
        => List(err)
    }
  }
  val messageAboutTiming = s"Retrieved data for ${task} in ${(System.nanoTime - t0) / 1000000} ms"

  val destination = if(errors.size == 0){
    task.destination
  } else {
    Paths.adaptDestinationForFailedResult(task.destination)
  }

  if(!result.isEmpty){
    ammonite.ops.write.over(destination,
      result.toStream
      .map{case(k,s) => k+"\t"+s.mkString("\t")+"\n"}
      .sorted
    )
  }

  errors.toList match {
    case List()
      => Right(messageAboutTiming)
    case xs
      => Left(s"${messageAboutTiming}\n ERRORS: \n ${xs.mkString("\n")}")
  }
}

def validate(tasks: Seq[Tasks.BioMartTask]) = {
  tasks
  .groupBy(_.species)
  .mapValues(_.map(_.ensemblAttributesInvolved).flatten.toSet)
  .map{ case(species, allAttributesWeWantFromEnsembl) =>
    BioMart.lookupAttributes(species)
    .right.map(_.map(_.propertyName).toSet)
    .right.flatMap { case bioMartAttributes =>
      (allAttributesWeWantFromEnsembl -- bioMartAttributes).toList match {
        case List()
          => Right(())
        case x
          => Left(s"Properties we wanted to request for species ${species} not found as BioMart attributes: ${x.mkString(", ")}")
      }
    }
  }
  .partition(_.isLeft) match {
    case (Nil,  _) => Right(())
    case (strings, _) => Left(for(Left(s) <- strings) yield s)
  }

}

//TODO: this should already be writing to logging streams - if it crashes the results are lost!
def performBioMartTasks(tasks: Seq[Tasks.BioMartTask]) = {

  validate(tasks) match {
    case Right(_)
      => {
        BioMart.BiomartAuxiliaryInfo.getMap(tasks.map{_.species}.toSet.toSeq)
        .right.map{ case aux =>
          Combinators.combine(
            //parallelize here
            tasks.map{case task =>

              performBioMartTask(aux,task)
            }
          )
        }
      }
    case Left(err)
      => {
        //You should probably log that validation didn't pass innit
        Left(err)
      }
  }
}
