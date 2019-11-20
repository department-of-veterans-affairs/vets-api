# frozen_string_literal: true

VAOS::Engine.routes.draw do
  defaults format: :json do
    resources :appointments, only: :index do
      put 'cancel', on: :collection
    end
    resources :appointment_requests, only: :index do
      resources :messages, only: :index
    end
    resources :systems, only: :index do
      resources :direct_scheduling_facilities, only: :index
    end
    resources :facilities, only: :index do
      resources :clinics, only: :index
      resources :cancel_reasons, only: :index
    end
    resources :preferences, only: :index
    get 'api', to: 'apidocs#index'
  end
end
3
