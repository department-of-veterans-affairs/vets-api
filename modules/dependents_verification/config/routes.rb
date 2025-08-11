# frozen_string_literal: true

DependentsVerification::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'form0538', to: 'claims#create'
    get 'form0538', to: 'claims#show'

    resources :claims, only: %i[create show]
  end
end
