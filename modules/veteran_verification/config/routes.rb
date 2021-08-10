# frozen_string_literal: true

VeteranVerification::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  get '/metadata', to: 'metadata#veteran_verification'

  namespace :v0 do
    resources :service_history, only: [:index]
    resources :disability_rating, only: [:index]
    resources :keys, only: [:index]
    resources :health, only: [:index]
    get 'status', to: 'veteran_status#index'
  end

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      get 'veteran_verification', to: 'api#veteran_verification'
    end
  end

  namespace :v1 do
    resources :service_history, only: [:index]
    resources :disability_rating, only: [:index]
    resources :keys, only: [:index]
    resources :health, only: [:index]
    get 'status', to: 'veteran_status#index'
  end

  namespace :docs do
    namespace :v1, defaults: { format: 'json' } do
      get 'veteran_verification', to: 'api#veteran_verification'
    end
  end
end
