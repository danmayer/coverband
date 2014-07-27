module Coverband
  class Middleware
    
    def initialize(app)
      @app = app
    end

    def call(env)
      Coverband::Base.instance.configure_sampling
      Coverband::Base.instance.record_coverage
      results = @app.call(env)
      Coverband::Base.instance.report_coverage
      results
    end
    
  end
end
