# frozen_string_literal: true

MedicalExpenseReports::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'form8416', to: 'claims#create'
    get 'form8416/:id', to: 'claims#show'

    resources :claims, only: %i[create show]
  end
end
