### 1.5.0

This is a major release with significant refactoring a stepping stone for a 2.0 release.

* staging a changes.md document!
* refactored out full abstraction for stores
* supports hit counts vs binary covered / not covered for lines
  * this will let you find density of code usage just not if it was used
  * this is a slight performance hit, so you can fall back to the old system if you want `redisstore.new(@redis, array: true)`
  * this is the primary new feature in 1.5.0
* Redis has configurable base name, so I can safely change storage formats between releases
* improved documentation
* supports `SimpleCov.root`
* show files that were never touched
* apply coverband filters to ignore files in report not just collection
* improved test coverage
* improved benchmarks including support for multiple stores ;)

### 1.3.1

* This was a small fix release addressing some issues
* mostly readme updates
* last release prior to having a changes document!