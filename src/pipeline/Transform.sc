import $file.Tasks
import $file.^.property.AtlasProperty
import AtlasProperty.{AtlasBioentityProperty,AtlasArrayDesign}
import $file.^.Directories

type Res = Seq[(String, Option[String])]

case class Transform(appliesForTask: Tasks.BioMartTask => Boolean, transform:  Res => Res)

private def lookupGo(v: Option[String]) : Option[String] = {
  v.flatMap(Directories.alternativeToCanonicalGoTermMapping.get(_))
  .orElse(v)
}
private val allTransforms = List(
  Transform(
    appliesForTask =
      (task: Tasks.BioMartTask) => {
        task.atlasProperty match {
          case AtlasBioentityProperty(_, _, "go")
            => true
          case _
            => false
        }
      },
    transform =
      (result: Res) => {
        result
        .map{case (k,v) => (k, lookupGo(v))}
      }),
  Transform(
    appliesForTask =
      (task: Tasks.BioMartTask) => {
        task.atlasProperty match {
          case AtlasArrayDesign(_, _)
            => true
          case _
            => false
        }
      },
    transform =
        (result: Res) => {
        result
        .groupBy(_._2)
        .filter {
          case (None, _)
            => true
          case (Some(probeSet), l)
            => l.map(_._1).toList match {
              case List(singleGene)
                => true
              case xs
                => {
                  false
                }
            }
        }.flatMap(_._2)
        .toList
      })
)

def transform(task: Tasks.BioMartTask, input: Res) = {
  allTransforms.foldRight(input)(
    (nextTransform: Transform, result: Res)
      => {
        if (nextTransform.appliesForTask(task)) {
          nextTransform.transform(result)
        } else {
          result
        }
    })
}
