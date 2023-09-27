# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportMonthlySubmissions, type: :job do
  before do
    claim = create(:auto_established_claim, :status_established) # TODO: make this a pact claim
    ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
    create(:auto_established_claim, :status_established)
  end

  describe '#perform' do
    let(:from) { 1.month.ago }
    let(:to) { Time.zone.now }

    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        Timecop.freeze
        submissions = ClaimsApi::ClaimSubmission.where(created_at: from..to)
        expect(ClaimsApi::SubmissionReportMailer).to receive(:build).once.with(
          from,
          to,
          submissions
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end
  end
end
