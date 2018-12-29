Rails.application.routes.draw do
  get 'dummy/show'
  mount Coverband::Reporters::Web.new, at: '/coverage'
end
