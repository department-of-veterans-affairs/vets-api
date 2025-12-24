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
        expected_recipients,
        consumer_claims_totals: [],
        poa_totals: [],
        ews_totals: [],
        itf_totals: []
      ).deliver_now
    end

    let(:recipient_loader) { Class.new { include ClaimsApi::ReportRecipientsReader }.new }
    let(:expected_recipients) { recipient_loader.load_recipients('submission_report_mailer') }

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Monthly Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to match_array(expected_recipients)
    end
  end
end
