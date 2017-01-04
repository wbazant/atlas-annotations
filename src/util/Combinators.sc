
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

//http://stackoverflow.com/questions/6489584/best-way-to-turn-a-lists-of-eithers-into-an-either-of-lists
def combine[A,B](data: Iterable[Either[A,B]]) : Either[Iterable[A], Iterable[B]] = {
  data.partition(_.isLeft) match {
    case (Nil,  results) => Right(for(Right(i) <- results) yield i)
    case (strings, _) => Left(for(Left(s) <- strings) yield s)
  }
}

/*
A module:

prepares itself for doing these tasks:
- figures out what auxiliary information it needs
- validates that it can do it

does them but at a pace the upstream wants:
- do requests

so, BioMart shouldn't know that we save results to a file :)

How about Future[Arg, Result]


def doAsync[In, Result](f: In => scala.concurrent.Future[Either[String, Result]])(ins: Seq[In])(implicit ec: scala.concurrent.ExecutionContext) = {
  //you can Future.sequence
}

*/
