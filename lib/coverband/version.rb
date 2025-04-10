# frozen_string_literal: true

###
# ensure we properly do release candidate versioning; https://github.com/danmayer/coverband/issues/288
# use format "4.2.1.rc.1" ~> 4.2.1.rc to prerelease versions like v4.2.1.rc.2 and v4.2.1.rc.3
###
module Coverband
  VERSION = "6.1.5"
end
