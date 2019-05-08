# frozen_string_literal: true

module Coverband
  class ReportMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      Collectors::Coverage.instance.report_coverage
    end
  end
end
