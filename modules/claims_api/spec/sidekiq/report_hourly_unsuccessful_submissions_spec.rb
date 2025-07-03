# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/report_hourly_unsuccessful_submissions'

describe ClaimsApi::ReportHourlyUnsuccessfulSubmissions, type: :job do
  subject { described_class.new }

  let(:messenger) { instance_double(ClaimsApi::Slack::FailedSubmissionsMessenger) }

  before do
    allow(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).and_return(messenger)
    allow(messenger).to receive(:notify!)
    allow_any_instance_of(described_class).to receive(:allow_processing?).and_return(true)

    # Allow all other `where` calls to pass through to the real implementation
    allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_call_original
    # Mock non-va.gov claims to ensure they are not picked up
    allow(ClaimsApi::AutoEstablishedClaim).to receive(:where)
      .with('status = ? AND created_at BETWEEN ? AND ? AND cid <> ?', 'errored', anything, anything, '0oagdm49ygCSJTp8X297')
      .and_return(double(pluck: []))
    allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: []))
    allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: []))
    allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: []))
  end

  describe '#perform' do
    it 'reports a single unresolved va.gov claim' do
      create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago, transaction_id: 'unresolved-1')

      expect(messenger).to receive(:notify!)
      subject.perform

      expect(subject.instance_variable_get(:@va_gov_errored_claims)).to eq(['unresolved-1'])
    end

    it 'does not report a resolved va.gov claim' do
      create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago, transaction_id: 'resolved-1')
      create(:auto_established_claim, :established, created_at: 10.minutes.ago, transaction_id: 'resolved-1, other data')

      expect(messenger).not_to receive(:notify!)
      subject.perform
    end

    it 'de-duplicates multiple errored claims for the same unresolved transaction' do
      create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago, transaction_id: 'unresolved-1, data-a')
      create(:auto_established_claim_va_gov, :errored, created_at: 20.minutes.ago, transaction_id: 'unresolved-1, data-b')

      expect(messenger).to receive(:notify!)
      subject.perform

      expect(subject.instance_variable_get(:@va_gov_errored_claims)).to eq(['unresolved-1'])
    end

    it 'does not report non-va.gov claims' do
      create(:auto_established_claim, :errored, created_at: 30.minutes.ago, transaction_id: 'should-be-ignored')
      expect(messenger).not_to receive(:notify!)
      subject.perform
    end

    it 'handles case-insensitive resolution' do
      create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago, transaction_id: 'CASE-TEST, data-a')
      create(:auto_established_claim, :established, created_at: 10.minutes.ago, transaction_id: 'case-test, data-b')

      expect(messenger).not_to receive(:notify!)
      subject.perform
    end

    it 'does not report anything when no errored claims exist' do
      expect(messenger).not_to receive(:notify!)
      subject.perform
    end
  end

  describe 'schedule' do
    sidekiq_file = Rails.root.join('lib', 'periodic_jobs.rb')
    lines = File.readlines(sidekiq_file).grep(/ClaimsApi::ReportHourlyUnsuccessfulSubmissions/i)
    schedule = lines.first.gsub("  mgr.register('", '').gsub("', 'ClaimsApi::ReportHourlyUnsuccessfulSubmissions')\n",
                                                             '')
    let(:parsed_schedule) { Fugit.do_parse(schedule) }

    it 'is scheduled to run every hour on the hour' do
      expect(parsed_schedule.minutes).to eq([0])
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Report Hourly Unsuccessful Submissions Job'
      msg = { 'class' => described_class,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: nil,
          detail: "Job retries exhausted for #{described_class}",
          error: error_msg
        )
      end
    end
  end
end
