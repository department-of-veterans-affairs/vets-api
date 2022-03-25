# frozen_string_literal: true

FactoryBot.define do
  factory :inherited_proof_verified_user_account, class: 'InheritedProofVerifiedUserAccount' do
    user_account { create(:user_account) }
  end
end
