# frozen_string_literal: true

VAOS::Engine.routes.draw do
  namespace :v2, defaults: { format: :json } do
    get 'apidocs', to: 'apidocs#index'
    get '/appointments', to: 'appointments#index'
    get '/appointments/:appointment_id', to: 'appointments#show'
    put '/appointments/:id', to: 'appointments#update'
    get 'community_care/eligibility/:service_type', to: 'cc_eligibility#show'
    get '/locations/:location_id/clinics', to: 'clinics#index'
    get '/locations/last_visited_clinic', to: 'clinics#last_visited_clinic'
    get '/locations/recent_clinics', to: 'clinics#recent_clinics'
    get '/locations/:location_id/clinics/:clinic_id/slots', to: 'slots#index'
    get '/locations/:location_id/slots', to: 'slots#facility_slots'
    get '/eligibility/', to: 'patients#index'
    get '/scheduling/configurations', to: 'scheduling#configurations'
    get '/facilities', to: 'facilities#index'
    get '/facilities/:facility_id', to: 'facilities#show'
    get '/relationships', to: 'relationships#index'
    post '/appointments', to: 'appointments#create'
  end
end
