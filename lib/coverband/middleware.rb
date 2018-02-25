# frozen_string_literal: true

module Coverband
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Coverband::Base.instance.configure_sampling
      Coverband::Base.instance.record_coverage
      @app.call(env)
    ensure
      Coverband::Base.instance.report_coverage
    end
  end
end
