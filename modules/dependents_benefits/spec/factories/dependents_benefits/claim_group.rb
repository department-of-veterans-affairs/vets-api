# frozen_string_literal: true

FactoryBot.define do
  factory :parent_claim_group, class: 'DependentsBenefits::MockClaimGroup' do
    transient do
      shared_id { SecureRandom.uuid }
    end

    parent_claim_id { shared_id }
    claim_id { shared_id } # Parent claim has same parent_claim_id and claim_id
    status { 'PENDING' }
    id { SecureRandom.uuid }

    initialize_with { new(parent_claim_id:, claim_id:, status:, id:) }
  end

  factory :claim_group, class: 'DependentsBenefits::MockClaimGroup' do
    parent_claim_id { SecureRandom.uuid }
    claim_id { SecureRandom.uuid }
    status { 'PENDING' }
    id { SecureRandom.uuid }

    initialize_with { new(parent_claim_id:, claim_id:, status:, id:) }
  end

  factory :sibling_claim_group, class: 'DependentsBenefits::MockClaimGroup' do
    parent_claim_id { SecureRandom.uuid }
    claim_id { SecureRandom.uuid } # Different from parent_claim_id to make it a sibling
    status { 'PENDING' }
    id { SecureRandom.uuid }

    initialize_with { new(parent_claim_id:, claim_id:, status:, id:) }
  end
end
