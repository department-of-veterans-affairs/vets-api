# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/report_hourly_unsuccessful_submissions'

describe ClaimsApi::ReportHourlyUnsuccessfulSubmissions, type: :job do
  subject { described_class.new }

  let(:messenger) { instance_double(ClaimsApi::Slack::FailedSubmissionsMessenger) }

  describe '#perform' do
    before do
      allow(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).and_return(messenger)
      allow(messenger).to receive(:notify!)
    end

    context 'when no errored submissions exist' do
      before do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled)
                                                            .and_return(true)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return([])
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return([])
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return([])
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return([])
      end

      it 'does not call notify method' do
        expect(messenger).not_to receive(:notify!)

        subject.perform
      end
    end

    context 'when errored submissions exist' do
      before do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled)
                                                            .and_return(true)
        time = 30.minutes.ago
        @poa = create(:power_of_attorney, :errored, created_at: time)
        @itf = create(:intent_to_file, :errored, created_at: time)
        @ews = create(:evidence_waiver_submission, :errored, created_at: time)
      end

      it 'calls notify with the correct parameters' do
        expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
          errored_disability_claims: [],
          errored_va_gov_claims: [],
          errored_poa: [@poa.id],
          errored_itf: [@itf.id],
          errored_ews: [@ews.id],
          from: kind_of(String),
          to: kind_of(String),
          environment: kind_of(String)
        )

        subject.perform
      end

      context 'when a va gov claim with the same transaction id errs in the same hour' do
        before do
          create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now, transaction_id: 'transaction_1')
          create(:auto_established_claim_va_gov, :errored, created_at: 59.minutes.ago, transaction_id: 'transaction_1')
        end

        it 'only alerts on one of the claims' do
          subject.perform

          expect(subject.instance_variable_get(:@va_gov_errored_claims)).to have_attributes(length: 1)
        end
      end

      context 'when dealing with va.gov claims' do
        it 'reports unresolved claims' do
          create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago,
                                                           transaction_id: 'unresolved-1')

          expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
            errored_disability_claims: [],
            errored_va_gov_claims: ['unresolved-1'],
            errored_poa: [@poa.id],
            errored_itf: [@itf.id],
            errored_ews: [@ews.id],
            from: kind_of(String),
            to: kind_of(String),
            environment: kind_of(String)
          )

          subject.perform
        end

        it 'does not alert for claims with specific errors' do
          error_text = described_class::NO_INVESTIGATION_ERROR_TEXT.first
          create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago,
                                                           evss_response: [{ 'status' => '422',
                                                                             'title' => 'Backend Service Exception',
                                                                             'detail' => error_text }])

          expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
            errored_disability_claims: [],
            errored_va_gov_claims: [],
            errored_poa: [@poa.id],
            errored_itf: [@itf.id],
            errored_ews: [@ews.id],
            from: kind_of(String),
            to: kind_of(String),
            environment: kind_of(String)
          )

          subject.perform
        end

        it 'does not report resolved claims' do
          create(:auto_established_claim_va_gov, :errored, created_at: 30.minutes.ago,
                                                           transaction_id: 'resolved-1')
          create(:auto_established_claim, :established, created_at: 10.minutes.ago,
                                                        transaction_id: 'resolved-1, other data')

          expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
            errored_disability_claims: [],
            errored_va_gov_claims: [],
            errored_poa: [@poa.id],
            errored_itf: [@itf.id],
            errored_ews: [@ews.id],
            from: kind_of(String),
            to: kind_of(String),
            environment: kind_of(String)
          )

          subject.perform
        end
      end
    end

    context 'when flipper is not enabled' do
      before do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled)
                                                            .and_return(false)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return(double(pluck: ['claim1']))
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: ['poa1']))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: ['itf1']))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews1']))
      end

      it 'does not run the alert' do
        expect(ClaimsApi::Slack::FailedSubmissionsMessenger).not_to receive(:new)

        subject.perform
      end
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
