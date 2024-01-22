# frozen_string_literal: true

Vye::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    resource :user_info, only: [:show], path: '/'
    resource :verifications, only: [:create], path: '/verify'
    resource :address_changes, only: [:create], path: '/address'
    resource :direct_deposit_changes, only: [:create], path: '/bank_info'
  end
end
