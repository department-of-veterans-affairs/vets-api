# frozen_string_literal: true

VaForms::Engine.routes.draw do
  match '/metadata', to: 'metadata#index', via: [:get]
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/v0/healthcheck', to: 'metadata#healthcheck', via: [:get]

  namespace :v0, defaults: { format: 'json' } do
    resources :forms, only: %i[index show]
  end
  namespace :docs do
    namespace :v0 do
      get 'api', to: 'api#index'
    end
  end
end
