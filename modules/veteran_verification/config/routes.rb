# frozen_string_literal: true

VeteranVerification::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :service_history, only: [:index]
    resources :disability_rating, only: [:index]
    get 'status', to: 'veteran_status#index'
  end

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      get 'service_history', to: 'api#history'
      get 'disability_rating', to: 'api#rating'
      get 'status', to: 'api#status'
      get 'metadata', to: 'api#metadata'
    end
  end
end
