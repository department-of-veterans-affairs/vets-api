# frozen_string_literal: true

TestUserDashboard::Engine.routes.draw do
  get 'tud_accounts', to: 'tud_accounts#index'
end
