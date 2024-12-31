# frozen_string_literal: true

VAForms::Engine.routes.draw do
  get '/metadata', to: 'metadata#index'
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  get '/v0/healthcheck', to: 'metadata#healthcheck'
  get '/v0/upstream_healthcheck', to: 'metadata#upstream_healthcheck'

  namespace :v0, defaults: { format: 'json' } do
    resources :forms, only: %i[index show]
  end
end
