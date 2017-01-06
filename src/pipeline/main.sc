import $file.Tasks
import $file.Retrieve

def runAll(logDirAbsolutePath: String) = {
  Retrieve.performBioMartTasks(ammonite.ops.Path(logDirAbsolutePath),Tasks.allTasks)
}
