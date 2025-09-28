# frozen_string_literal: true

SurvivorsBenefits::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'form534ez', to: 'claims#create'
    get 'form534ez/:id', to: 'claims#show'

    resources :claims, only: %i[create show]
  end
end
