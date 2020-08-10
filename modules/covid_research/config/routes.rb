CovidResearch::Engine.routes.draw do
  namespace :volunteer, defaults: { format: :json } do
    post 'create', to: 'submissions#create'
  end
end
