# frozen_string_literal: true

IncomeAndAssets::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'form0969', to: 'claims#create'
    get 'form0969', to: 'claims#show'

    resources :claims, only: %i[create show]
  end
end
