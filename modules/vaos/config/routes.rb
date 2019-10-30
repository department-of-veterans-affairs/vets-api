# frozen_string_literal: true

VAOS::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    resources :systems, only: :index
    get 'api', to: 'apidocs#index'
  end
end
