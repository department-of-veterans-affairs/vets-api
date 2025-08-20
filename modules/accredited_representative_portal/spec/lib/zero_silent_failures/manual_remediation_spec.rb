# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ZeroSilentFailures::ManualRemediation do
  let(:claim) { create(:saved_claim_benefits_intake) }

  def stub_claim_class_resolution
    allow(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake)
      .to receive(:form_class_from_proper_form_id)
      .and_return(SavedClaim)

    allow(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
  end

  describe '#stamps' do
    it 'returns base stamps plus ARP-specific stamp' do
      stub_claim_class_resolution

      remediation = described_class.new(claim.id)

      timestamp = Time.zone.now
      stamps = remediation.send(:stamps, timestamp)

      expect(stamps.length).to eq(2)

      expect(stamps.first).to include(x: 5, y: 5, timestamp:)

      expect(stamps.second).to include(
        text: 'Representative Submission via VA.gov',
        x: 400,
        y: 770,
        timestamp:
      )
    end
  end

  describe '#generate_metadata' do
    it 'merges lighthouse attempt UUID and date into metadata' do
      stub_claim_class_resolution

      form_submission = create(:form_submission, saved_claim_id: claim.id)
      attempt = create(
        :form_submission_attempt,
        form_submission:,
        benefits_intake_uuid: SecureRandom.uuid,
        created_at: Time.zone.now
      )

      remediation = described_class.new(claim.id)
      metadata = remediation.send(:generate_metadata)

      expect(metadata).to include(
        lighthouseBenefitIntakeSubmissionUUID: attempt.benefits_intake_uuid,
        lighthouseBenefitIntakeSubmissionDate: attempt.created_at
      )

      expect(metadata).to include(
        claimId: claim.id,
        docType: claim.form_id,
        claimConfirmation: attempt.benefits_intake_uuid
      )
    end
  end
end
