import $file.BioMart
import $file.Tasks
import $file.Transform
import $file.^.Log
import $file.^.Paths
import $file.^.^.util.Combinators
import $file.^.^.property.AnnotationSource
import AnnotationSource.AnnotationSource


private def lineOk(line:String) = {
  // ignore empty lines and lines with first empty reference column
  line.takeWhile(_!='\t').filter(!Character.isWhitespace(_)).size > 0
}

//private
def performBioMartTask(aux:Map[AnnotationSource, BioMart.BiomartAuxiliaryInfo], task: Tasks.BioMartTask) : Either[String, String] = {
  val readResults : PartialFunction[String, Either[String,(String,Option[String])]] = {
    case line if lineOk(line) => {
      (line.map(_.isValidChar).reduce(_&&_), line.split("\t")) match {
        case (true, Array(k))
          => Right((k, None))
        case (true, Array(k, v))
          => Right((k, Some(v)))
        case _
          => Left(s"Result for ${task} contains invalid line: ${line}")
      }
    }
  }

  val t0 = System.nanoTime
  val x =
    task.queries
    .map { case (filters, attributes) =>
      BioMart.fetchFromBioMart(aux)(task.annotationSource, filters, attributes)
    }.map {
      case Right(res: Array[String])
        => res.collect(readResults)
      case Left(err)
        => Array(Left(err))
    }
  val result = for(returnedResult <- x; Right(line) <- returnedResult) yield line
  val errors = for(returnedResult <- x; Left(err) <- returnedResult) yield err

  val messageAboutTiming = s"Retrieved data for ${task} in ${(System.nanoTime - t0) / 1000000} ms"

  Paths.writeResult(
    destination = task.destination,
    result =
      Transform.transform(task,result)
      .sorted // the output needs to be sorted as equivalent to Unix's join -k1,1
      .distinct // skip duplicate lines - biomart's uniqueRows="1" can't be trusted unfortunately
      .collect { //the output really needs to be rectangular so that the files can be understood by R
        case (k, Some(v))
          => s"${k}\t${v}\n"
      }
      .toStream,
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
      validateAttributesPresentInBioMart(tasks)
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
def validateAttributesPresentInBioMart(tasks: Seq[Tasks.BioMartTask]) :Either[Iterable[String],_]= {
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

def performBioMartTasks(tasks: Seq[Tasks.BioMartTask]) = {
  val tasksToComplete = tasks.filter(!_.seemsDone)
  if(tasksToComplete.size < tasks.size) {
      Log.log(s"Skipped tasks that seem completed, remaining ${tasksToComplete.size} tasks")
  }
  Log.log(s"Validating ${tasksToComplete.size} tasks")
  validate(tasksToComplete) match {
    case Right(_)
      => {
        Log.log(s"Validated ${tasksToComplete.size} tasks")
        BioMart.BiomartAuxiliaryInfo.getMap(tasksToComplete.map{_.annotationSource}.toSet.toSeq) match {
          case Right(auxiliaryInfo)
            => {
              Log.log(s"Retrieved auxiliary info of ${auxiliaryInfo.size} items")
              var errorCount = 0
              val executorService = java.util.concurrent.Executors.newFixedThreadPool(10)
              for(task <- tasksToComplete) {
                  executorService.submit(new java.lang.Runnable {
                      def run = {
                          performBioMartTask(auxiliaryInfo, task) match {
                              case Left(l)
                                => {
                                    Log.err(l)
                                    errorCount+=1
                                }
                              case Right(r)
                                => Log.log(r)
                          }
                      }
                  })
              }
              executorService.shutdown()
              executorService.awaitTermination(8, java.util.concurrent.TimeUnit.HOURS)

              Log.log("Finished!")
              errorCount
            }
          case Left(err)
            => {
              Log.err("Failed retrieving auxiliary info:")
              Log.err(err)
              1
            }
        }
      }
    case Left(err)
      => {
        Log.err(err)
        1
      }
  }
}
