module Coverband
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      begin
        Coverband::Base.instance.configure_sampling
        Coverband::Base.instance.record_coverage
      rescue
        # we don't want to interrupt web request with any error from this gem
      end

      @app.call(env)
    ensure
      begin
        Coverband::Base.instance.report_coverage
      rescue
        # we don't want to interrupt web request with any error from this gem
      end
    end

  end
end
