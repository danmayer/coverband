class DummyViewController < ActionController::Base
  def show
    @text = "I am no dummy view tracker text"
    render layout: false
  end

  def show_haml
    @text = "I am haml text"
    render layout: false
  end

  def show_slim
    @text = "I am slim text"
    render layout: false
  end
end
