# frozen_string_literal: true

TestUserDashboard::Engine.routes.draw do
  resources :tud_accounts, only: %i[index update]
end
