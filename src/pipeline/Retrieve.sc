import $file.Tasks
import $file.BioMart
import $file.^.util.Combinators
import $file.Log
import scala.concurrent._
import scala.util.{Success, Failure}
import $file.^.property.AnnotationSource
import AnnotationSource.AnnotationSource

import collection.mutable.{ HashMap, Set }

//private
def performBioMartTask(aux:Map[AnnotationSource, BioMart.BiomartAuxiliaryInfo], task: Tasks.BioMartTask) : Either[String, String] = {

  val result = new HashMap[String, Set[String]]

  val t0 = System.nanoTime
  val errors = task.queries.flatMap { case (filters, attributes) =>
    BioMart.fetchFromBioMart(aux)(task.annotationSource, filters, attributes) match {
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

  Paths.writeResult(
    destination = task.destination,
    result =
      result.toStream
      .map{case(k,s) => k+"\t"+s.mkString("\t")+"\n"}
      .sorted,
    hasErrors = errors.size > 0
   )

  errors.toList match {
    case List()
      => Right(messageAboutTiming)
    case xs
      => Left(s"${messageAboutTiming}\n ERRORS: \n ${xs.mkString("\n")}")
  }
}
def validate(tasks: Seq[Tasks.BioMartTask]) = {
  Combinators.combine(
    List(
      validateDestinationsUnique(tasks),
      validateAttributesCorrect(tasks)
    )
  )
}

def validateDestinationsUnique(tasks: Seq[Tasks.BioMartTask]) :Either[Iterable[String],_] = {
  tasks
  .groupBy{_.destination}
  .filter {
    case (destination, tasksPerDestination)
      => tasksPerDestination.length > 1
  }
  .map {
    case (destination, tasksPerDestination) =>
    "Conflicting - same destinations: ${tasksPerDestination.mkString(\", \")}"
  }
  .toList match {
    case List()
      => Right(())
    case x
      => Left(x)
  }
}
def validateAttributesCorrect(tasks: Seq[Tasks.BioMartTask]) :Either[Iterable[String],_]= {
  tasks
  .groupBy(_.annotationSource)
  .mapValues(_.map(_.ensemblAttributesInvolved).flatten.toSet)
  .map{ case(annotationSource, allAttributesWeWantFromEnsembl) =>
    BioMart.lookupAttributes(annotationSource)
    .right.map(_.map(_.propertyName).toSet)
    .right.flatMap { case bioMartAttributes =>
      (allAttributesWeWantFromEnsembl -- bioMartAttributes).toList match {
        case List()
          => Right(())
        case x
          => Left(s"Validation error, properties for annotationSource ${annotationSource} not found in BioMart as valid attributes: ${x.mkString(", ")}")
      }
    }
  }
  .partition(_.isLeft) match {
    case (Nil,  _) => Right(())
    case (strings, _) => Left(for(Left(s) <- strings) yield s)
  }
}

def scheduleAndLogResultOfBioMartTask(aux:Map[AnnotationSource, BioMart.BiomartAuxiliaryInfo])
  (task : Tasks.BioMartTask)(implicit ec: ExecutionContext) = {
  if(task.seemsDone){
    Log.log(s"Task appears done, skipping: ${task}")
  } else {
    future {
      performBioMartTask(aux, task) match {
        case Right(msg)
          => Log.log(msg)
        case Left(err)
          => Log.err(err)
      }
    } onFailure {
      /*
      this is not ideal because it gets submitted to a pool I think and might not happen for a while.
      Anyway we do not expect this kind of failure.
      */
       case e => {
         Log.err(s"Fatal failure for task: {task}")
         Log.err(e)
       }
    }
  }
}

def performBioMartTasks(tasks: Seq[Tasks.BioMartTask]) = {
  validate(tasks) match {
    case Right(_)
      => {
        Log.log(s"Validated ${tasks.size} tasks")
        val aux = BioMart.BiomartAuxiliaryInfo.getMap(tasks.map{_.annotationSource}.toSet.toSeq)
        aux match {
          case Right(auxiliaryInfo)
            => {
              Log.log(s"Retrieved auxiliary info of ${auxiliaryInfo.size} items")

              val executorService = java.util.concurrent.Executors.newFixedThreadPool(10)
              val ec : ExecutionContext = scala.concurrent.ExecutionContext.fromExecutorService(executorService)
              for(task <- tasks) {
                scheduleAndLogResultOfBioMartTask(auxiliaryInfo)(task)(ec)
              }
              Thread.sleep(1000)
            }
          case Left(err)
            => {
              Log.err("Failed retrieving auxiliary info:")
              Log.err(err)
            }
        }
      }
    case Left(err)
      => {
        Log.err(err)
      }
  }
}
