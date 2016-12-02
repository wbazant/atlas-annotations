import $file.Tasks
import $file.BioMart
import $file.^.property.Species
import Species.Species
import $file.^.util.Combinators
import $file.Log
import scala.concurrent._
import scala.util.{Success, Failure}

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
          => Left(s"Validation error, properties for species ${species} not found in BioMart as valid attributes: ${x.mkString(", ")}")
      }
    }
  }
  .partition(_.isLeft) match {
    case (Nil,  _) => Right(())
    case (strings, _) => Left(for(Left(s) <- strings) yield s)
  }
}

def scheduleAndLogResultOfBioMartTask(logOut: Any => Unit, logErr: Any => Unit,
    aux:Map[Species, BioMart.BiomartAuxiliaryInfo])
  (task : Tasks.BioMartTask)(implicit ec: ExecutionContext) = {
  future {
    performBioMartTask(aux, task)
  } onComplete {
    case Success(Right(msg))
      => logOut(msg)
    case Success(Left(err))
      => logErr(err)
    case Failure(e)
      => logErr(e)
  }
}

//TODO: this should already be writing to logging streams - if it crashes the results are lost!
def performBioMartTasks(runId: String, tasks: Seq[Tasks.BioMartTask]) = {
  val logOut = Log.log(runId, "biomart")(_)
  val logErr = Log.err(runId, "biomart")(_)

  validate(tasks) match {
    case Right(_)
      => {
        logOut(s"Validated ${tasks.size} tasks")
        val aux = BioMart.BiomartAuxiliaryInfo.getMap(tasks.map{_.species}.toSet.toSeq)
        aux match {
          case Right(auxiliaryInfo)
            => {
              logOut(s"Retrieved auxiliary info of ${auxiliaryInfo.size} items")

              val executorService = java.util.concurrent.Executors.newFixedThreadPool(10)
              val ec : ExecutionContext = scala.concurrent.ExecutionContext.fromExecutorService(executorService)
              for(task <- tasks) {
                scheduleAndLogResultOfBioMartTask(logOut, logErr, auxiliaryInfo)(task)(ec)
              }
              executorService.shutdown()
            }
          case Left(err)
            => logErr("Failed retrieving auxiliary info: "+err)
        }
      }
    case Left(err)
      => {
        logErr(err)
      }
  }
}
