import $file.retrieve.Tasks
import $file.retrieve.Retrieve

def runAll() = {
  Retrieve.performBioMartTasks(Tasks.allTasks)
}
