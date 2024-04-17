# frozen_string_literal: true

InProgressForms::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    resources :in_progress_forms, only: %i[index show update destroy]

    get 'hello', to: 'in_progress_forms#hello'
  end
end
