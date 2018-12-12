# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :appeals, only: [:index]
    get 'healthcheck', to: 'appeals#healthcheck'
    resources :claims, only: %i[index show]
  end

  namespace :docs do
    namespace :v0 do
      # DEPRECATED DOC LINK (To be removed)
      get 'api', to: 'api#appeals'
      # -------------------
      get 'appeals', to: 'api#appeals'
      get 'claims', to: 'api#claims'
    end
  end
end
