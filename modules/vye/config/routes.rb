# frozen_string_literal: true

Vye::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    resource :user_info, only: [:show], path: '/'
    resource :verifications, only: [:create], path: '/verify'
    resource :address_changes, only: [:create], path: '/address'
    resource :direct_deposit_changes, only: [:create], path: '/bank_info'

    post 'dgib_verifications/verification_record', to: 'dgib_verifications#verification_record'
    post 'dgib_verifications/verify_claimant', to: 'dgib_verifications#verify_claimant'
    post 'dgib_verifications/claimant_status', to: 'dgib_verifications#claimant_status'
    get 'dgib_verifications/claimant_lookup', to: 'dgib_verifications#claimant_lookup'
  end
end
