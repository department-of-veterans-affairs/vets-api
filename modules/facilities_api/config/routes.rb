# frozen_string_literal: true

FacilitiesApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    resources :ccp, only: :index do
      get 'specialties', on: :collection, to: 'ccp#specialties'
    end
    resources :va, only: %i[index show]
  end
end
