# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StemApplicantDenialMailer, type: [:mailer] do
  subject do
    described_class.build(education_benefits_claim, ga_client_id).deliver_now
  end

  let(:education_benefits_claim) do
    claim = build(:education_benefits_claim_10203)
    claim.save
    claim
  end
  let(:applicant) { education_benefits_claim.saved_claim.open_struct_form }
  let(:ga_client_id) { '123456543' }

  describe '#build' do
    it 'includes subject' do
      expect(subject.subject).to eq(StemApplicantDenialMailer::SUBJECT)
    end

    it 'includes recipients' do
      expect(subject.to).to eq([applicant.email])
    end

    context 'applicant information in email body' do
      it 'includes date received' do
        date_received = education_benefits_claim.saved_claim.created_at.strftime('%b %d, %Y')
        expect(subject.body.raw_source).to include(date_received)
      end

      it 'includes claim status url' do
        env = FeatureFlipper.staging_email? ? 'staging.' : ''
        claim_status_url = "https://#{env}va.gov/track-claims/your-stem-claims/#{education_benefits_claim.id}/status"
        expect(subject.body.raw_source).to include(claim_status_url)
      end
    end
  end
end
