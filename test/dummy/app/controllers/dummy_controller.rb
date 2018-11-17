class DummyController < ActionController::API
  def show
    render plain: "I am no dummy"
  end
end
