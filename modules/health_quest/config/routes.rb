# frozen_string_literal: true

HealthQuest::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :appointments, only: %i[index show]
    resources :pgd_questionnaires, only: %i[show]
    resources :patients, only: %i[create]
    resources :questionnaires, only: %i[index show]
    resources :questionnaire_responses, only: %i[index show create]

    get 'questionnaire_manager', to: 'questionnaire_manager#index'
    get 'signed_in_patient', to: 'patients#signed_in_patient'
    get 'apidocs', to: 'apidocs#index'
  end
end
