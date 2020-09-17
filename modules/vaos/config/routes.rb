# frozen_string_literal: true

VAOS::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :appointments, only: %i[index create] do
      put 'cancel', on: :collection
    end
    resources :appointment_requests, only: %i[index create update] do
      resources :messages, only: %i[index create]
    end
    get 'community_care/eligibility/:service_type', to: 'cc_eligibility#show'
    get 'community_care/supported_sites', to: 'cc_supported_sites#index'
    resources :systems, only: :index do
      resources :direct_scheduling_facilities, only: :index
      resources :pact, only: :index
      resources :clinic_institutions, only: :index
    end
    resources :facilities, only: :index do
      resources :clinics, only: :index
      resources :cancel_reasons, only: :index
      resources :available_appointments, only: :index
      resources :limits, only: :index
      get 'visits/:schedule_type', to: 'visits#index'
    end
    resource :preferences, only: %i[show update]
    resources :direct_booking_eligibility_criteria, only: :index
    resources :request_eligibility_criteria, only: :index
    get 'apidocs', to: 'apidocs#index'
  end

  namespace :v1, defaults: { format: :json } do
    get '/Appointment/', to: 'appointments#index'
    get '/HealthcareService', to: 'healthcare_services#index'
    get '/Location/:id', to: 'locations#show'
    get '/Organization', to: 'organizations#index'
    get '/Organization/:id', to: 'organizations#show'
    get '/Patient', to: 'patients#index'
    get '/Slot', to: 'slots#index'
    post '/Appointment', to: 'appointments#create'
    put '/Appointment/:id', to: 'appointments#update'
  end
end
