# frozen_string_literal: true

VAOS::Engine.routes.draw do
  resources :appointments, only: %i[index], defaults: { format: :json }
  resources :appointment_requests, only: %i[index], defaults: { format: :json }
  resources :systems, only: :index, defaults: { format: :json }
  get 'api', to: 'apidocs#index', defaults: { format: :json }
end
