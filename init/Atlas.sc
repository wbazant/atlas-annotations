//get IntelliJ to make jars in lib directory
//copy oracle jars - see new joiner page
import ammonite.ops._
import ammonite.ops.ImplicitWd._
interp.load.cp(ammonite.ops.pwd/"lib")
ls! pwd/'lib |! interp.load.cp //load all the jars
