import $file.^.Directories
import Directories._

import ammonite.ops._

//private
def logDirectory(runId: String) = {
  val p = LOG / runId
  mkdir! p
  p
}

private def formatLogLine(line: String) = {
  val now = new java.text.SimpleDateFormat("yyyy-MM-dd:HH:mm:ss").format(new java.util.Date())
  s"${now}: $line\n"
}
private def writeToFile(runId: String, fileName: String, message: Any) : Unit = {
  message match {
    case s: String
      => write.append(logDirectory(runId) / fileName , formatLogLine(s))
    case seq : Iterable[_]
      => seq.map(writeToFile(runId,fileName,_))
    case e : Throwable
      => writeToFile(
        runId,
        fileName,
        if(e.getMessage() !=null) {e.getMessage() } else  {e.toString()}
      )
    case x
      => writeToFile(runId,fileName, x.toString)
  }
}

def log(runId: String, operationName: String)(message: Any) = {
  writeToFile(runId, operationName + ".log" , message)
}
def err(runId: String, operationName: String)(message: Any) = {
  writeToFile(runId, operationName + ".err" , message)
}
