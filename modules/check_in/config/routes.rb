# frozen_string_literal: true

CheckIn::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :patient_check_ins, only: %i[show create]
  end
end
