# frozen_string_literal: true

RepresentationManagement::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    resources :flag_accredited_representatives, only: %i[create]
  end
end
