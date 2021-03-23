# frozen_string_literal: true

CovidVaccine::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'registration', to: 'registration#show'
    post 'registration', to: 'registration#create'
    post 'registration/unauthenticated', to: 'registration#create'
    put 'registration/opt_out', to: 'registration#opt_out'
    put 'registration/opt_in', to: 'registration#opt_in'

    get 'facilities/:zip', to: 'facilities#index'
  end
end
