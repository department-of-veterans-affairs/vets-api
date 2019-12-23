# frozen_string_literal: true

VeteranConfirmation::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    post 'status', to: 'veteran_status#index'
  end

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      get 'status', to: 'api#status'
    end
  end
end
