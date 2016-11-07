

/*
This is just a doodle of how to combine results.
Don't be too attached to it. :)
*/
def doAll[In](f: In => Either[String, _])(ins: Seq[In]) : Either[String, Unit] = {
  ins.flatMap{ case in =>
    f(in) match {
      case Left(err)
        => Some((in,err))
      case Right(())
        => None
    }
  }.toList match {
    case List()
      => Right(())
    case x
      => Left(s"${x.size} errors:\n ${x.mkString("\n")}")
  }
}

def speciesList() = ammonite.ops.ls(Annsrcs.annsrcsPath).map(_.segments.last)
