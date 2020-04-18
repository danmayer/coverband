class DummyController < ActionController::Base
  def show
    render plain: "I am no dummy"
  end
end
