# frozen_string_literal: true

module Coverband
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      AtExit.register
      if Coverband.configuration.background_reporting_enabled
        Background.start
      else
        Collectors::Coverage.instance.report_coverage
      end
    end
  end
end
