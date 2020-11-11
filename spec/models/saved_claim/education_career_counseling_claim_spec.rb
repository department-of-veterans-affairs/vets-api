# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::EducationCareerCounselingClaim do
  let(:claim) { create(:education_career_counseling_claim_no_vet_information) }
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }

  describe '#add_claimant_info' do
    it 'adds veteran information' do
      claim.add_claimant_info(user_object)

      expect(claim.parsed_form).to include(
        'claimantInformation' => {
          'fullName' => {
            'first' => 'WESLEY',
            'middle' => '',
            'last' => 'FORD'
          },
          'veteranSocialSecurityNumber' => '796043735',
          'dateOfBirth' => '1809-02-12'
        }
      )
    end
  end

  describe '#regional_office' do
    it 'returns an empty array for regional office' do
      expect(claim.regional_office).to eq([])
    end
  end
end
