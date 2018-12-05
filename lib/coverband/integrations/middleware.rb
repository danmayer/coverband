# frozen_string_literal: true

module Coverband
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      if Coverband.configuration.background_reporting_enabled
        Coverband::Background.start
      else
        Coverband::Collectors::Coverage.instance.report_coverage
      end
    end
  end
end
