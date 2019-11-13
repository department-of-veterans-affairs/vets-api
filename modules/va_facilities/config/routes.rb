# frozen_string_literal: true

VaFacilities::Engine.routes.draw do
  match '/metadata', to: 'metadata#index', via: [:get]
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/v1/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0 do
    resources :facilities, only: %i[index show] do
      get 'all', on: :collection
    end
    resources :nearby, only: [:index]
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end

    namespace :v1 do
      resources :api, only: [:index]
    end
  end
end
