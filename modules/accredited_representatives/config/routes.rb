# frozen_string_literal: true

AccreditedRepresentatives::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'arbitrary', to: 'arbitrary#arbitrary'
  end
end
