# frozen_string_literal: true

AccreditedRepresentativePortal::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :power_of_attorney_requests, only: [:index] do
      member do
        post :accept
        post :decline
      end
    end

    get 'user', to: 'representative_users#show'
  end

  post '/accreditation/applications/form21a', to: 'application#form21a'
end
