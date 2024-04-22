# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::EducationCareerCounselingClaim do
  let(:claim) { create(:education_career_counseling_claim_no_vet_information) }
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }

  describe '#regional_office' do
    it 'returns an empty array for regional office' do
      expect(claim.regional_office).to eq([])
    end
  end

  describe '#send_to_benefits_intake!' do
    it 'formats data before sending to central mail or benefits intake' do
      allow(claim).to receive(:process_attachments!)

      expect(claim).to receive(:update).with(form: a_string_including('"veteranSocialSecurityNumber":"333224444"'))

      claim.send_to_benefits_intake!
    end

    it 'calls process_attachments! method' do
      expect(claim).to receive(:process_attachments!)
      claim.send_to_benefits_intake!
    end

    context 'Feature ecc_benefits_intake_submission is true' do
      before do
        Flipper.enable(:ecc_benefits_intake_submission)
      end

      it 'calls Lighthouse::SubmitBenefitsIntakeClaim job' do
        expect_any_instance_of(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform).with(claim.id)
        claim.send_to_benefits_intake!
      end
    end

    context 'Feature ecc_benefits_intake_submission is false' do
      before do
        Flipper.disable(:ecc_benefits_intake_submission)
      end

      it 'calls CentralMail::SubmitSavedClaimJob job' do
        expect_any_instance_of(CentralMail::SubmitSavedClaimJob).to receive(:perform).with(claim.id)
        claim.send_to_benefits_intake!
      end
    end
  end
end
