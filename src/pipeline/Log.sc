private def formatLogLine(line: String) = {
  val now = new java.text.SimpleDateFormat("yyyy-MM-dd:HH:mm:ss").format(new java.util.Date())
  s"${now}: $line"
}
private def writeToFile(stream : java.io.PrintStream, message: Any) : Unit = {
  message match {
    case s: String
      => stream.println(formatLogLine(s))
    case seq : Iterable[_]
      => seq.map(writeToFile(stream,_))
    case e : Throwable
      => writeToFile(
        stream,
        if(e.getMessage() !=null) {e.getMessage() } else  {e.toString()}
      )
    case x
      => writeToFile(stream, x.toString)
  }
}

def log(message: Any) = {
  writeToFile(System.out, message)
}
def err(message: Any) = {
  writeToFile(System.err, message)
}
