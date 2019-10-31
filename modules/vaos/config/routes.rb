# frozen_string_literal: true

VAOS::Engine.routes.draw do
  match '/metadata', to: 'metadata#index', via: [:get]
  match '/v0/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :appointments, only: %i[index]
    resources :systems, only: :index
    get 'api', to: 'apidocs#index'
  end
end
