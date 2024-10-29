# frozen_string_literal: true

Vye::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    resource :user_info, only: [:show], path: '/'
    resource :verifications, only: [:create], path: '/verify'
    resource :address_changes, only: [:create], path: '/address'
    resource :direct_deposit_changes, only: [:create], path: '/bank_info'

    get 'verifications/get_verification_record', to: 'verifications#get_verification_record'
    get 'verifications/verify_claimant', to: 'verifications#verify_claimant'
    get 'verifications/get_claimant_status', to: 'verifications#get_claimant_status'
    get 'verifications/claimant_lookup', to: 'verifications#claimant_lookup'
  end
end
