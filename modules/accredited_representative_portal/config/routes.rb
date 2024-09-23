# frozen_string_literal: true

AccreditedRepresentativePortal::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'user', to: 'representative_users#show'

    post 'form21a', to: 'form21a#submit'

    resources :in_progress_forms, only: %i[update show destroy]
  end
end
