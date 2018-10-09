# frozen_string_literal: true

module Coverband
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      Coverband::Collectors::Base.instance.report_coverage
    end
  end
end
