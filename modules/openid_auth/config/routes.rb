# frozen_string_literal: true

OpenidAuth::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v2, defaults: { format: 'json' } do
    post 'validation', to: 'validation#index'
  end

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      get 'mvi-user', to: 'mpi_users#index'
    end
    namespace :v2, defaults: { format: 'json' } do
      get 'validation', to: 'validation#index'
    end
  end
end
