# frozen_string_literal: true

require "rack"

class HelloWorld
  def call(_env)
    [200, {"content-type" => "text/html"}, "Hello Rack!"]
  end
end
