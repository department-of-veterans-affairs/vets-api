# frozen_string_literal: true

VAOS::Engine.routes.draw do
  defaults format: :json do
    resources :appointments, only: :index
    resources :appointment_requests, only: :index
    resources :systems, only: :index
    resources :facilities, only: :index
    get 'api', to: 'apidocs#index'
  end
end
