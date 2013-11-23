require File.expand_path('../test_helper', File.dirname(__FILE__))

class MiddlewareTest < Test::Unit::TestCase
  
  FAKE_RESULTS = 'results'

  should "call app" do
    middleware = Coverband::Middleware.new(fake_app)
    results = middleware.call({})
    assert_equal FAKE_RESULTS, results
  end

  private

  def fake_app
    @app ||= begin 
              my_app = OpenStruct.new()
              def my_app.call(env)
                FAKE_RESULTS
              end
              my_app
            end
  end

end
