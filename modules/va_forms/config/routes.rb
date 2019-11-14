# frozen_string_literal: true

VaForms::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :forms, only: %i[index show]
  end
  namespace :docs do
    namespace :v0 do
      get 'api', to: 'api#index'
    end
  end
end
