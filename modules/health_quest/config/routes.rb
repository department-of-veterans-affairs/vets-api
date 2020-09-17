# frozen_string_literal: true

HealthQuest::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :appointments, only: %i[index show] do
    end
    resources :pgd_questionnaires, only: %i[show] do
    end
    resources :pgd_ques_responses, only: %i[show] do
    end
  end
end
