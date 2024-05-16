# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SubmissionReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      from = 1.month.ago
      to = Time.zone.now

      claim = create(:auto_established_claim, :status_established)
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
      pact_act_submission = ClaimsApi::ClaimSubmission.where(created_at: from..to)

      described_class.build(
        from,
        to,
        pact_act_data,
        consumer_claims_totals: [],
        poa_totals: [],
        ews_totals: [],
        itf_totals: []
      ).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Monthly Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          alex.wilson@oddball.io
          austin.covrig@oddball.io
          emily.goodrich@oddball.io
          jennica.stiehl@oddball.io
          kayla.watanabe@adhocteam.us
          matthew.christianson@adhocteam.us
          rockwell.rice@oddball.io
        ]
      )
    end
  end
end
