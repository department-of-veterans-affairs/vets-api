# frozen_string_literal: true

CheckIn::Engine.routes.draw do
  match '/check_in/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/check_in/v1/*path', to: 'application#cors_preflight', via: [:options]
  match '/check_in/v2/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: :json } do
    resources :patient_check_ins, only: %i[show create]
  end

  namespace :v1, defaults: { format: :json } do
    resources :patient_check_ins, only: %i[show create]
    resources :sessions, only: %i[show create]
  end

  namespace :v2, defaults: { format: :json } do
    resources :patient_check_ins, only: %i[show create]
    resources :sessions, only: %i[show create]
    resources :pre_check_ins, only: %i[show create]

    get 'apidocs', to: 'apidocs#index'
  end
end
