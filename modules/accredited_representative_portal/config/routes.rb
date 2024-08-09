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

    post 'form21a', to: 'form21a#submit'

    resources :in_progress_forms, only: %i[update show destroy]
  end
end
