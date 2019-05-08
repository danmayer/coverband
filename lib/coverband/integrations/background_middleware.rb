# frozen_string_literal: true

module Coverband
  class BackgroundMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      AtExit.register
      Background.start if Coverband.configuration.background_reporting_enabled
    end
  end
end
