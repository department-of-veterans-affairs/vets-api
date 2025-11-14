# frozen_string_literal: true

EmploymentQuestionnaires::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'form4140', to: 'claims#create'
    get 'form4140/:id', to: 'claims#show'

    resources :claims, only: %i[create show]
  end
end
