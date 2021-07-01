# frozen_string_literal: true

HealthQuest::Engine.routes.draw do
  match '/health_quest/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: :json } do
    resources :lighthouse_appointments, only: %i[index show]
    resources :locations, only: %i[index show]
    resources :organizations, only: %i[index show]
    resources :pgd_questionnaires, only: %i[show]
    resources :patients, only: %i[create]
    resources :questionnaires, only: %i[index show]
    resources :questionnaire_responses, only: %i[index show create]
    resources :questionnaire_manager, only: %i[index show create]

    get 'signed_in_patient', to: 'patients#signed_in_patient'
    get 'apidocs', to: 'apidocs#index'
  end
end
