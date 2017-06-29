import $file.retrieve.Tasks
import $file.retrieve.Retrieve
import $file.is_ready.PropertiesAdequate
import $file.Log

@main
def runAll(force:Boolean=false) = {
  Log.log("Going through experiment directories to verify our annotation sources")
  (PropertiesAdequate.main,force) match {
    case (Left(err),false)
      => {
        Log.log("Failed validation - annotation sources not sufficient, see err")
        Log.err(err)
        System.exit(1)
      }
    case (t, _)
      => {
        Log.log(t.right.map(Function.const("Validated annotation sources contain the array designs we need")).merge)
        Retrieve.performBioMartTasks(
            Tasks.allTasks
        )
      }
  }
}
