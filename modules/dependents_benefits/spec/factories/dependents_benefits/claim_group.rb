# frozen_string_literal: true

FactoryBot.define do
  factory :saved_claim_group, class: 'SavedClaimGroup' do
    status { 'pending' }
    user_data { { user_uuid: SecureRandom.uuid } }

    transient do
      parent_claim { create(:dependents_claim) }
      saved_claim { create(:add_remove_dependents_claim) }
    end

    parent_claim_id { parent_claim.id }

    saved_claim_id { saved_claim.id }

    claim_group_guid { parent_claim.guid }
  end

  factory :parent_claim_group, class: 'SavedClaimGroup' do
    status { 'pending' }
    user_data { { user_uuid: SecureRandom.uuid } }

    transient do
      parent_claim { create(:dependents_claim) }
    end

    parent_claim_id { parent_claim.id }

    saved_claim_id { parent_claim_id }

    claim_group_guid { parent_claim.guid }
  end
end
