CovidVaccineTrial::Engine.routes.draw do
  namespace :screener, defaults: { format: :json } do
    post 'create', to: 'submissions#create'
  end
end
