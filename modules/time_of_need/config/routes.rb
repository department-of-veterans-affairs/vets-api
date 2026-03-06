# frozen_string_literal: true

TimeOfNeed::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :claims, only: %i[create show]
  end
end
