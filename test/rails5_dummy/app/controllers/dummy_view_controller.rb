class DummyViewController < ActionController::Base
  def show
    @text = "I am no dummy view tracker text"
    render layout: false
  end
end
