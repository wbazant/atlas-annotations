import $file.retrieve.Tasks
import $file.retrieve.Retrieve
import $file.is_ready.PropertiesAdequate
import $file.Log

def runAll() = {
  Log.log("Going through experiment directories to verify our annotation sources")
  PropertiesAdequate.main match {
    case Left(err)
      => {
        Log.err("FAILED FAILED FAILED YOU SHOULD STOP THIS MADNESS")
        Log.err(err)
        Log.err("""
          TODO we try validate the experiments have the array designs they need in Ensembl files.
          Some of them are missing and it's okay because they're retrieved from mirbase.
          Add a clause for them, and make failed falidation stop the run.
          """)
        Log.log("Continuing despite validation failure")
        forceAll()
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
