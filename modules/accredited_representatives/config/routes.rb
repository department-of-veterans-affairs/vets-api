# frozen_string_literal: true

AccreditedRepresentatives::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    post 'power_of_attorney/accept', to: 'power_of_attorney#accept'
  end
end
