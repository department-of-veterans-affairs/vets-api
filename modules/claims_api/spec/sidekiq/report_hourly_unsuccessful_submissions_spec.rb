# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/report_hourly_unsuccessful_submissions'

describe ClaimsApi::ReportHourlyUnsuccessfulSubmissions, type: :job do
  subject { described_class.new }

  describe '#perform' do
    context 'when no errored submissions exist' do
      before do
        # rubocop:disable Layout/LineLength
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled).and_return(true)
        # rubocop:enable Layout/LineLength
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return([])
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return([])
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return([])
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return([])
      end

      it 'does not call notify method' do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).not_to receive(:notify)
        # rubocop:enable RSpec/SubjectStub
        subject.perform
      end
    end

    context 'when errored submissions exist' do
      before do
        # rubocop:disable Layout/LineLength
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled).and_return(true)
        # rubocop:enable Layout/LineLength
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return(double(pluck: ['claim1']))
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: ['poa1']))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: ['itf1']))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews1']))
      end

      it 'calls notify with the correct parameters' do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:notify).with(
          ['claim1'],
          [],
          ['poa1'],
          ['itf1'],
          ['ews1'],
          kind_of(String),
          kind_of(String),
          kind_of(String)
        )
        # rubocop:enable RSpec/SubjectStub

        subject.perform
      end
    end

    context 'when flipper it not enabled' do
      before do
        # rubocop:disable Layout/LineLength
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled).and_return(false)
        # rubocop:enable Layout/LineLength
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return(double(pluck: ['claim1']))
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: ['poa1']))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: ['itf1']))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews1']))
      end

      it 'does not run the alert' do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).not_to receive(:notify).with(
          ['claim1'],
          ['claim2'],
          ['poa1'],
          ['itf1'],
          ['ews1'],
          kind_of(String),
          kind_of(String),
          kind_of(String)
        )
        # rubocop:enable RSpec/SubjectStub

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
