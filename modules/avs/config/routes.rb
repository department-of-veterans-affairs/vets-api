# frozen_string_literal: true

Avs::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get '/avs/search', to: 'avs#index'
    get '/avs/:sid', to: 'avs#show'

    resources :apidocs, only: [:index]
  end
end
