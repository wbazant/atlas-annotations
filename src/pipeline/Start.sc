import $file.retrieve.Tasks
import $file.retrieve.Retrieve
import $file.is_ready.PropertiesAdequate
import $file.Log

@main
def runAll() = {
  Log.log("Going through experiment directories to verify our annotation sources")
  PropertiesAdequate.main match {
    case Left(err)
      => {
        Log.log("Failed validation - annotation sources not sufficient")
        Log.err(err)
      }
    case Right(_)
      => {
        Log.log("Validated annotation sources contain the array designs we need")
        forceAll()
      }
  }
}

def forceAll() = {
  Retrieve.performBioMartTasks(Tasks.allTasks)
}