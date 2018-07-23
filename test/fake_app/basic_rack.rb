# frozen_string_literal: true

require 'rack'

class HelloWorld
  def call(_env)
    [200, { 'Content-Type' => 'text/html' }, 'Hello Rack!']
  end
end
