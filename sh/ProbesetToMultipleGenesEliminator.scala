/**
 * Created by rpetry on 04/05/2014.
 *
 * This script removes from the provided file all probe-sets mapping to multiple genes
 */
object ProbesetToMultipleGenesEliminator {
  def main(args: Array[String]) {
    val fName: String = args(0)

    def prettyPrint(t: Tuple2[String, String]) = println(t._1 + "\t" + t._2)

    /**
     *
     * @param allMappings all gene to probe-set mappings
     * @param prev previous line from the mapping file
     * @param multiple true if probe-set from previous line has multiple gene mappings; false otherwise
     */
    def excludeProbsetsMappingToMultipleGenes(
                                               allMappings: List[Tuple2[String, String]],
                                               prev: Tuple2[String, String],
                                               multiple: Boolean): Unit = {
      if (!allMappings.isEmpty) {
        var nextMultiple: Boolean = false
        // prev probe-set is different from the current
        if (!allMappings.head._2.equals(prev._2)) {
          // previous probe-set did not map to multiple genes - report it
          if (!multiple) prettyPrint(prev)
        } else {
          nextMultiple = true
        }
        excludeProbsetsMappingToMultipleGenes(allMappings.tail, allMappings.head, nextMultiple)
      } else if (!multiple) {
        // prev = last line in file: if its probe-set did not map to multiple genes - report it
        prettyPrint(prev)
      }
    }

    val allMappings = scala.io.Source.fromFile(fName)
      .getLines
      .drop(1) // drop header
      .map(_.split("\t"))
      .map(a => Tuple2(a(0), a(1)))
      .toList.sortBy(_._2)

    excludeProbsetsMappingToMultipleGenes(allMappings.tail, allMappings.head, false)
  }
}


