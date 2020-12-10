# frozen_string_literal: true

CovidVaccine::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'registration', to: 'registration#show'
    post 'registration', to: 'registration#create'
    post 'registration/unauthenticated', to: 'registration#create'
  end
end
