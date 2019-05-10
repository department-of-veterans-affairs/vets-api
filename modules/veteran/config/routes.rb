# frozen_string_literal: true

Veteran::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  namespace :v0, defaults: { format: 'json' } do
    get 'representatives/find_rep', to: 'representatives#find_rep'
  end
end
