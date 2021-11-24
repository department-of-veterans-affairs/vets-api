# frozen_string_literal: true

AppsApi::Engine.routes.draw do
  get '/metadata', to: 'metadata#index'
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  get '/v0/healthcheck', to: 'metadata#healthcheck'

  namespace :v0, defaults: { format: 'json' } do
    scope_default = { category: 'unknown_category' }
    get 'directory/scopes/:category', to: 'directory#scopes', defaults: scope_default
    get 'directory/scopes', to: 'directory#scopes', defaults: scope_default
    resources 'directory'
  end

  namespace :docs do
    namespace :v0 do
      get 'api', to: 'api#index'
    end
  end
end
