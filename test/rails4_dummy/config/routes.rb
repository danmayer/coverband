Rails.application.routes.draw do
  get "dummy/show"
  get "dummy_view/show", to: "dummy_view#show"
  get "dummy_view/show_haml", to: "dummy_view#show_haml"
  get "dummy_view/show_slim", to: "dummy_view#show_slim"
  mount Coverband::Reporters::Web.new, at: "/coverage"
end
