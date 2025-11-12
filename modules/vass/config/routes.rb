# frozen_string_literal: true

Vass::Engine.routes.draw do
  match '/vass/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: :json } do
    resources :sessions, only: %i[show create]
    resources :appointments, only: %i[index show create]

    get 'apidocs', to: 'apidocs#index'
  end
end
