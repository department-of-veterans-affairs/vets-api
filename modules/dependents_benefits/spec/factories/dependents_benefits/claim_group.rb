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
    user_data do
      {
        'veteran_information' => {
          'full_name' => {
            'first' => 'Michael',
            'middle' => 'James',
            'last' => 'Johnson'
          },
          'birth_date' => '1978-03-22',
          'common_name' => 'Mike Johnson',
          'va_profile_email' => 'mike.johnson@email.com',
          'email' => 'mjohnson@gmail.com',
          'participant_id' => '12345678',
          'ssn' => '555-44-3333',
          'va_file_number' => 'claim-file-456',
          'uuid' => 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'icn' => '1012667890V123456'
        }
      }.to_json
    end

    transient do
      parent_claim { create(:dependents_claim) }
    end

    parent_claim_id { parent_claim.id }

    saved_claim_id { parent_claim_id }

    claim_group_guid { parent_claim.guid }
  end
end
