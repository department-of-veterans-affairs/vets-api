# frozen_string_literal: true

IncreaseCompensation::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'form8940', to: 'claims#create'
    get 'form8940/:id', to: 'claims#show'

    resources :claims, only: %i[create show]
  end
end
