# frozen_string_literal: true

VAForms::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :forms, only: %i[index show]
  end
end
