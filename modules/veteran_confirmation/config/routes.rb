# frozen_string_literal: true

VeteranConfirmation::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      get 'api', to: 'api#index'
    end
  end
end
