# frozen_string_literal: true

Vye::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post 'dgib_verifications/verification_record', to: 'dgib_verifications#verification_record'
    post 'dgib_verifications/verify_claimant', to: 'dgib_verifications#verify_claimant'
    post 'dgib_verifications/claimant_status', to: 'dgib_verifications#claimant_status'
    get 'dgib_verifications/claimant_lookup', to: 'dgib_verifications#claimant_lookup'
  end
end
