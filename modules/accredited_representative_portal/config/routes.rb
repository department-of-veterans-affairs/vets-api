# frozen_string_literal: true

AccreditedRepresentativePortal::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'user', to: 'representative_users#show'

    post 'form21a', to: 'form21a#submit'

    resources :in_progress_forms, only: %i[update show destroy]
    resources :power_of_attorney_requests, only: [:index, :show] do
      post 'decision', to: 'power_of_attorney_requests#decision'
      get 'decision', to: 'power_of_attorney_requests#get_decision'
    end
  end
end
