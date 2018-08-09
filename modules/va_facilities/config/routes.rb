# frozen_string_literal: true

VaFacilities::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0 do
    resources :facilities, only: [:index, :show] do
      get 'all', on: :collection
    end
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end
  end
end
