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
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: ['poa1']))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: ['itf1']))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews1']))
      end

      it 'calls notify with the correct parameters' do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:notify).with(
          [],
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

      # rubocop:disable RSpec/NoExpectationExample
      it 'does not repeat an alert based on transaction id' do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled)
                                                            .and_return(true)

        claim_one = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now,
                                                                                transaction_id: 'transaction_1',
                                                                                id: '1')
        claim_two = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: 2.hours.ago,
                                                                                transaction_id: 'transaction_1',
                                                                                id: '2')
        claim_three = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now,
                                                                                  transaction_id: 'transaction_2',
                                                                                  id: '3')
        claim_four = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now,
                                                                                 transaction_id: 'transaction_3',
                                                                                 id: '4')

        expected_vagov_claims = [claim_three.id, claim_four.id]
        expected_absent_values = [claim_one.id, claim_two.id]

        expected_present_values = [
          [],
          expected_vagov_claims,
          ['poa1'],
          ['itf1'],
          ['ews1']
        ]

        expected_results(expected_vagov_claims, expected_absent_values, expected_present_values)

        subject.perform
      end

      it 'does not alert for claims with specific errors' do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_hourly_slack_error_report_enabled)
                                                            .and_return(true)

        claim_one = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now,
                                                                                transaction_id: 'transaction_1',
                                                                                id: '1')
        claim_two = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: 2.hours.ago,
                                                                                transaction_id: 'transaction_1',
                                                                                id: '2')
        claim_three = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now,
                                                                                  transaction_id: 'transaction_2',
                                                                                  id: '3')
        claim_four = FactoryBot.create(:auto_established_claim_va_gov, :errored, created_at: Time.zone.now,
                                                                                 transaction_id: 'transaction_3',
                                                                                 id: '4')

        claim_five = FactoryBot.create(:auto_established_claim_va_gov,
                                       :errored,
                                       created_at: 30.seconds.ago,
                                       evss_response: [{ 'status' => '422',
                                                         'title' => 'Backend Service Exception',
                                                         'detail' => 'The Maximum number of EP codes have been ' \
                                                                     'reached for this benefit type claim code' }],
                                       transaction_id: 'transaction_4')

        claim_six = FactoryBot.create(:auto_established_claim_va_gov,
                                      :errored,
                                      created_at: 120.seconds.ago,
                                      evss_response: [{ 'status' => '422',
                                                        'title' => 'Backend Service Exception',
                                                        'detail' => 'Claim could not be established. ' \
                                                                    'Retries will fail.' }],
                                      transaction_id: 'transaction_5')

        expected_vagov_claims = [claim_three.id, claim_four.id]
        expected_absent_values = [claim_one.id, claim_two.id, claim_five.id, claim_six.id]

        expected_present_values = [
          [],
          expected_vagov_claims,
          ['poa1'],
          ['itf1'],
          ['ews1']
        ]

        expected_results(expected_vagov_claims, expected_absent_values, expected_present_values)

        subject.perform
      end
    end
    # rubocop:enable RSpec/NoExpectationExample

    def expected_results(expected_vagov_claims, expected_absent_values, expected_present_values)
      # rubocop:disable RSpec/SubjectStub
      expect(subject).to receive(:notify) do |*args|
        args.each_with_index do |arg, idx|
          if [5, 6, 7].include?(idx)
            expect(arg).to be_a(String)
          elsif idx == 1
            expect(arg.flatten).to include(*expected_vagov_claims)
            expect(arg.flatten).not_to include(*expected_absent_values)
          else
            expect(expected_present_values).to include(arg)
            expect(expected_absent_values.flatten).not_to include(arg)
          end
        end
      end
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when flipper is not enabled' do
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
