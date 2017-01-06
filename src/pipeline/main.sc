import $file.Tasks
import $file.Retrieve

def runAll() = {
  Retrieve.performBioMartTasks(Tasks.allTasks)
}
