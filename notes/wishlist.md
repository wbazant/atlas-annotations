# Wishlist

### new codebase structure
#### split into:
  + commons (Java, no Spring)
  + webapp (Java+Spring, deploys as a WAR)
  + dataprod (Scala/Ammonite)

##### What's in commons
Things that at some point in the past we wanted to reuse.
###### You want to reuse an Atlas class?
  + unspringify it
  + move it to commons

##### dataprod has access to:
  + commons
  + Right JdbcTemplate(so springframework jar, oracle jars, right config)
  + current dataprod (bash/perl)

### dataprod structure
  + scalamain
    + pure scala classes/objects
    + imports
      + ammonite.ops._
      + commons(Java)
    + models data production and pipeline problems
    + target to move shell/perl over to
  + base setup
    + import commons+ commons dependencies(ideally none?)
    + import minimal amount of jars (springframework jar, oracle jars)
    + import all our scala
    + expose:
      + some globals like where current dataprod is
      + right jdbcTemplate
  + dev setup
    + inherits from base setup
    + import the whole folder of Atlas jars
  + task runners
    + inherits from base setup
    + one per pipeline operation
    + can use current dataprod (invoking bash/perl)
    + can send tasks to lsf

### environments

#### local
  + work on Java in IntelliJ
  + build commons on IntelliJ make
  + write and run unit tests for scalamain
  + can work in Ammonite shell - task runners possibly won't run
  + safe setup to run scripts in
  + can restore setup anytime
  + can extend setup and push new setup with code

#### lime
  + gets newest code on commit
  + includes new commons
  + run unit tests for scalamain on commit
  + access IT database (maybe)
  + report failure if we should not deploy to ebi-005: project setup is broken or tests fail

#### ebi-005
  + gets newest code on manual deploy
  + runs as fg_atlas
  + prod environment
  + Ammonite shell runs
  + can explore and do things for the first time but with care
  + can update task runners
  + can run task runners from crontab
  + can store logs



### notes
- I am not sure if one setup can inherit from another actually. At worst sync them through copy and paste.
- You can't send tasks to lsf from local, so the local setup will never be complete
- will we not reuse configuration.properties?
  + probably not
  + can improve and extend AtlasResource:
    - ExperimentDirectoryResource(String experimentDataLocation)
    - PerExperimentResource
    - PerContrastResource
    - PerArrayDesignAndContrastResource
