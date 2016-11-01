// Get IntelliJ to make jars in lib directory
import ammonite.ops._
import ammonite.ops.ImplicitWd._
ls! pwd/'lib |! interp.load.cp //load all the jars
