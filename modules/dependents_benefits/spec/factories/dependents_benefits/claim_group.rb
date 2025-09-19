# frozen_string_literal: true

FactoryBot.define do
  factory :saved_claim_group do
    claim_group_guid { SecureRandom.uuid }
    status { 'pending' }
    user_data { { user_uuid: SecureRandom.uuid } }

    # Use the same SavedClaim for both parent and child
    transient do
      claim { create(:dependents_claim) }
    end

    parent_claim_id { claim.id }
    saved_claim_id { claim.id }

    trait :with_children do
      after(:create) do |claim_group|
        # Create two additional child claims with the same parent and claim_group_guid
        2.times do
          child_claim = create(:dependents_claim)
          create(:saved_claim_group,
                 claim_group_guid: claim_group.claim_group_guid,
                 parent_claim_id: claim_group.parent_claim_id,
                 saved_claim_id: child_claim.id)
        end
      end
    end
  end
end
