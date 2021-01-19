# frozen_string_literal: true

HealthQuest::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :appointments, only: %i[index show]
    resources :pgd_questionnaires, only: %i[show]
    resources :questionnaires, only: %i[index show]
    resources :questionnaire_responses, only: %i[index show create]

    get 'apidocs', to: 'apidocs#index'
  end
end
