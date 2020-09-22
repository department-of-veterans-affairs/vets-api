# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::EducationCareerCounselingClaim do
  let(:claim) { create(:education_career_counseling_claim_no_vet_information) }
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }

  describe '#add_veteran_info' do
    it 'adds veteran information' do
      claim.add_veteran_info(user_object)

      expect(claim.parsed_form).to include(a_hash_including(:foo))
    end
  end
end
