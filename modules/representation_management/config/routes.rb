# frozen_string_literal: true

RepresentationManagement::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    resources :accredited_individuals, only: %i[index]
    resources :accredited_entities_for_appoint, only: %i[index]
    resources :flag_accredited_representatives, only: %i[create]
    resources :pdf_generator2122, only: %i[create]
    resources :pdf_generator2122a, only: %i[create]
    resources :power_of_attorney, only: %i[index]
    get 'apidocs', to: 'apidocs#index'
  end
end
