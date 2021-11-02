# frozen_string_literal: true

TestUserDashboard::Engine.routes.draw do
  get '/oauth/is_authorized', to: 'oauth#authenticated_and_authorized?'
  get '/oauth/logout', to: 'oauth#logout'
  resources :oauth, only: [:index]
  resources :tud_accounts, only: %i[index update]
end
