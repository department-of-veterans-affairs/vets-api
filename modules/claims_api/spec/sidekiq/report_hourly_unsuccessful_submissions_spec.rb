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
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: ['poa1']))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: ['itf1']))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews1']))
      end

      it 'calls notify with the correct parameters' do
        create(:auto_established_claim, :errored, transaction_id: 'claim1, other data', cid: 'not-vagov',
                                                  created_at: 30.minutes.ago)

        expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
          unresolved_errored_claims: [{ transaction_id: 'claim1', is_va_gov: false }],
          errored_poa: ['poa1'],
          errored_itf: ['itf1'],
          errored_ews: ['ews1'],
          from: kind_of(String),
          to: kind_of(String),
          environment: kind_of(String)
        )

        subject.perform
      end

      it 'does not repeat an alert based on transaction id' do
        create(:auto_established_claim, :errored, transaction_id: 't1, other data',
                                                  cid: described_class::VAGOV_CID, created_at: 30.minutes.ago)
        create(:auto_established_claim, :errored, transaction_id: 't2, other data', cid: 'not-vagov',
                                                  created_at: 30.minutes.ago)

        expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
          unresolved_errored_claims: contain_exactly(
            { transaction_id: 't1', is_va_gov: true },
            { transaction_id: 't2', is_va_gov: false }
          ),
          errored_poa: ['poa1'],
          errored_itf: ['itf1'],
          errored_ews: ['ews1'],
          from: kind_of(String),
          to: kind_of(String),
          environment: kind_of(String)
        )

        subject.perform
      end

      context 'when a va gov claim with the same transaction id errs in the same hour' do
        it 'only alerts on one of the claims' do
          create(:auto_established_claim, :errored, transaction_id: 't1, other data',
                                                    cid: described_class::VAGOV_CID, created_at: 30.minutes.ago)
          create(:auto_established_claim, :errored, transaction_id: 't1, more data',
                                                    cid: described_class::VAGOV_CID, created_at: 20.minutes.ago)
          subject.perform
          expect(subject.instance_variable_get(:@unresolved_claims)).to eq(
            [{ transaction_id: 't1', is_va_gov: true }]
          )
        end
      end

      it 'does not alert for claims with specific errors' do
        create(:auto_established_claim, :errored, transaction_id: 't2, other data', cid: 'not-vagov',
                                                  created_at: 30.minutes.ago)
        create(:auto_established_claim, :errored, transaction_id: 't3, other data',
                                                  cid: described_class::VAGOV_CID, created_at: 30.minutes.ago)
        # This one should be ignored because it is resolved
        create(:auto_established_claim, :errored, transaction_id: 't4, other data', cid: 'not-vagov',
                                                  created_at: 30.minutes.ago)
        create(:auto_established_claim, :established, transaction_id: 't4, resolved data', cid: 'not-vagov',
                                                      created_at: 25.minutes.ago)

        expect(ClaimsApi::Slack::FailedSubmissionsMessenger).to receive(:new).with(
          unresolved_errored_claims: contain_exactly(
            { transaction_id: 't2', is_va_gov: false },
            { transaction_id: 't3', is_va_gov: true }
          ),
          errored_poa: ['poa1'],
          errored_itf: ['itf1'],
          errored_ews: ['ews1'],
          from: kind_of(String),
          to: kind_of(String),
          environment: kind_of(String)
        )

        subject.perform
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

  describe '#transaction_id_extracted' do
    let(:job) { described_class.new }

    it 'extracts the ID from a standard transaction_id string' do
      id = 'Form526Submission_3662922, user_uuid: [filtered], service_provider: lighthouse'
      expect(job.send(:transaction_id_extracted, id)).to eq('form526submission_3662922')
    end

    it 'handles transaction_ids with no comma' do
      id = 'Form526Submission_12345'
      expect(job.send(:transaction_id_extracted, id)).to eq('form526submission_12345')
    end

    it 'is case-insensitive' do
      id = 'FORM526SUBMISSION_98765, some_other_data'
      expect(job.send(:transaction_id_extracted, id)).to eq('form526submission_98765')
    end

    it 'returns nil for a nil transaction_id' do
      expect(job.send(:transaction_id_extracted, nil)).to be_nil
    end

    it 'handles an empty string' do
      expect(job.send(:transaction_id_extracted, '')).to be_nil
    end
  end

  describe '#find_unresolved_errored_claims' do
    before do
      # Set time window for the job
      subject.instance_variable_set(:@search_from, 1.hour.ago)
      subject.instance_variable_set(:@search_to, Time.zone.now)
    end

    let!(:errored_unresolved) do
      create(:auto_established_claim, :errored, transaction_id: 'unresolved_123, user_uuid: abc',
                                                cid: 'some-other-cid',
                                                created_at: 30.minutes.ago)
    end
    let!(:errored_resolved) do
      create(:auto_established_claim, :errored, transaction_id: 'resolved_456, user_uuid: def',
                                                created_at: 30.minutes.ago)
    end
    let!(:errored_resolved_also) do
      create(:auto_established_claim, :errored, transaction_id: 'resolved_456, user_uuid: def',
                                                created_at: 30.minutes.ago)
    end
    let!(:established_claim) do
      create(:auto_established_claim, :established, transaction_id: 'resolved_456, user_uuid: ghi',
                                                    created_at: 30.minutes.ago)
    end
    let!(:old_errored) do
      create(:auto_established_claim, :errored, created_at: 2.hours.ago, transaction_id: 'old_789, user_uuid: jkl')
    end
    let!(:errored_no_id) do
      create(:auto_established_claim, :errored, transaction_id: nil)
    end
    let!(:errored_case_sensitive) do
      create(:auto_established_claim, :errored, transaction_id: 'CASE_SENSITIVE, user_uuid: mno',
                                                created_at: 30.minutes.ago)
    end
    let!(:established_case_sensitive) do
      create(:auto_established_claim, :established, transaction_id: 'case_sensitive, user_uuid: pqr',
                                                    created_at: 30.minutes.ago)
    end

    it 'only returns transaction IDs for unresolved claims in the time window' do
      unresolved_claims = subject.send(:find_unresolved_errored_claims)
      expect(unresolved_claims.count).to eq(1)
      expect(unresolved_claims.first[:transaction_id]).to eq('unresolved_123')
      expect(unresolved_claims.first[:is_va_gov]).to be(false)
    end

    context 'when no errored claims are found' do
      before { ClaimsApi::AutoEstablishedClaim.where(status: 'errored').destroy_all }

      it 'returns an empty array' do
        expect(subject.send(:find_unresolved_errored_claims)).to be_empty
      end
    end

    it 'correctly identifies it as resolved' do
      unresolved_ids = subject.send(:find_unresolved_errored_claims).map { |c| c[:transaction_id] }
      expect(unresolved_ids).not_to include('case_sensitive')
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
