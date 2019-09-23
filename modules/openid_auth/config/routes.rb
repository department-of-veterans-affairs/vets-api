# frozen_string_literal: true

OpenidAuth::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    get 'validation', to: 'validation#index'
    get 'mvi-user', to: 'mvi_users#show'
    post 'mvi-user', to: 'mvi_users#search'
    post 'okta', to: 'okta#okta_callback'
  end

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      get 'validation', to: 'validation#index'
      get 'mvi-user', to: 'mvi_users#index'
      get 'okta', to: 'okta_controller#index'
    end
  end
end
