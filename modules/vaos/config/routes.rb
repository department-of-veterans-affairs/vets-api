# frozen_string_literal: true

VAOS::Engine.routes.draw do
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

  namespace :v2, defaults: { format: :json } do
    get 'apidocs', to: 'apidocs#index'
    get '/appointments', to: 'appointments#index'
    get '/appointments/:appointment_id', to: 'appointments#show'
    put '/appointments/:id', to: 'appointments#update'
    get 'community_care/eligibility/:service_type', to: 'cc_eligibility#show'
    get '/locations/:location_id/clinics', to: 'clinics#index'
    get '/locations/:location_id/clinics/:clinic_id/slots', to: 'slots#index'
    get '/eligibility/', to: 'patients#index'
    get '/scheduling/configurations', to: 'scheduling#configurations'
    get '/facilities', to: 'facilities#index'
    get '/facilities/:facility_id', to: 'facilities#show'
    post '/appointments', to: 'appointments#create'
  end
end
