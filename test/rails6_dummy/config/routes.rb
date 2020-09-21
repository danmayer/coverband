Rails.application.routes.draw do
  get "dummy/show"
  get "dummy_view/show", to: "dummy_view#show"
  mount Coverband::Reporters::Web.new, at: "/coverage"
end
