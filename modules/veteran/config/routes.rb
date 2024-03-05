# frozen_string_literal: true

Veteran::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  namespace :v0, defaults: { format: 'json' } do
    get 'representatives/find_rep', to: 'representatives#find_rep'
    resources :vso_accredited_representatives, only: %i[index]
    resources :other_accredited_representatives, only: %i[index]
    get 'apidocs', to: 'apidocs#index'
  end
end
