# frozen_string_literal: true

DigitalFormsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: :json } do
    resources :submissions, only: %i[create show]
  end
end
