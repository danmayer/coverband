module Coverband
  class Middleware < Base
    
    def set_app(app)
      @app = app
      self
    end

    def call(env)
      configure_sampling
      record_coverage
      results = @app.call(env)
      report_coverage
      results
    end
    
  end
end
