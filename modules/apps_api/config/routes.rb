# frozen_string_literal: true

AppsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

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
