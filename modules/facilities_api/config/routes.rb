# frozen_string_literal: true

FacilitiesApi::Engine.routes.draw do
  namespace :v2, defaults: { format: 'json' } do
    resources :ccp, only: :index do
      collection do
        get 'urgent_care',  to: 'ccp#urgent_care'
        get 'provider',     to: 'ccp#provider'
        get 'pharmacy',     to: 'ccp#pharmacy'
        get 'specialties',  to: 'ccp#specialties'
      end
    end

    get 'va/:id', to: 'va#show'
    post 'va', to: 'va#search', as: 'va_search'

    get 'apidocs', to: 'apidocs#index'
  end
end
