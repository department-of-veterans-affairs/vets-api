# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ZeroSilentFailures::ManualRemediation do
  let(:claim) { create(:saved_claim_benefits_intake) }

  describe '#stamps' do
    it 'returns base stamps plus ARP-specific stamp' do
      claim_class_double = class_double(AccreditedRepresentativePortal::SavedClaim::AnyFormClass, find: claim)
      allow(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake)
        .to receive(:form_class_from_proper_form_id)
        .and_return(claim_class_double)

      remediation = described_class.new(claim.id)

      timestamp = Time.zone.now
      stamps = remediation.send(:stamps, timestamp)

      # Base provides 1, ARP adds 1
      expect(stamps.length).to eq(2)

      # Base stamp (comes from shared SavedClaim remediation)
      expect(stamps.first).to include(x: 5, y: 5, timestamp:)

      # ARP-specific stamp
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
      claim_class_double = class_double(AccreditedRepresentativePortal::SavedClaim::AnyFormClass, find: claim)
      allow(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake)
        .to receive(:form_class_from_proper_form_id)
        .and_return(claim_class_double)

      form_submission = create(:form_submission, saved_claim_id: claim.id)
      attempt = create(:form_submission_attempt,
                       form_submission:,
                       benefits_intake_uuid: SecureRandom.uuid,
                       created_at: Time.zone.now)

      remediation = described_class.new(claim.id)
      metadata = remediation.send(:generate_metadata)

      expect(metadata).to include(
        lighthouseBenefitIntakeSubmissionUUID: attempt.benefits_intake_uuid,
        lighthouseBenefitIntakeSubmissionDate: attempt.created_at
      )
    end
  end
end
