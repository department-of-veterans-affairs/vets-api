# frozen_string_literal: true

AccreditedRepresentatives::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resource :users, only: [] do
      get 'show', on: :collection
      get 'icn', on: :collection
    end
  end
end
