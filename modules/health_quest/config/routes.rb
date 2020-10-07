# frozen_string_literal: true

HealthQuest::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :appointments, only: %i[index show] do
    end
  end
end
