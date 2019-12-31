# frozen_string_literal: true

VAOS::Engine.routes.draw do
  defaults format: :json do
    resources :appointments, only: :index do
      put 'cancel', on: :collection
    end
    resources :appointment_requests, only: %i[index create update] do
      resources :messages, only: %i[index create]
    end
    get 'community_care/eligibility/:service_type', to: 'cc_eligibility#show'
    resources :systems, only: :index do
      resources :direct_scheduling_facilities, only: :index
      resources :pact, only: :index
    end
    resources :facilities, only: :index do
      resources :clinics, only: :index
      resources :cancel_reasons, only: :index
      resources :available_appointments, only: :index
      resources :limits, only: :index
      get 'visits/:schedule_type', to: 'visits#index'
    end
    resource :preferences, only: %i[show update]
    get 'api', to: 'apidocs#index'
  end
end
