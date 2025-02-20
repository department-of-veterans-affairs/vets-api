# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SubmissionReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      from = 1.month.ago
      to = Time.zone.now

      claim = create(:auto_established_claim, :established)
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'

      described_class.build(
        from,
        to,
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
          drew.fisher@adhocteam.us
          emily.goodrich@oddball.io
          jennica.stiehl@oddball.io
          kayla.watanabe@adhocteam.us
          matthew.christianson@adhocteam.us
          rockwell.rice@oddball.io
          tyler.coleman@oddball.io
          Janet.Coutinho@va.gov
          Michael.Harlow@va.gov
        ]
      )
    end
  end
end
