# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_dmc_service'

RSpec.describe DebtsApi::V0::DigitalDisputeJob, type: :worker do
  describe '#perform' do
    let(:user) { create(:user, :loa3) }
    let!(:submission) do
      create(:debts_api_digital_dispute_submission,
             user_uuid: user.uuid,
             user_account: user.user_account,
             state: :pending)
    end

    let(:mpi_service) { instance_double(MPI::Service) }
    let(:mpi_profile) { OpenStruct.new(participant_id: user.participant_id, ssn: user.ssn) }
    let(:mpi_resp)    { OpenStruct.new(profile: mpi_profile) }

    before do
      stub_const('MPI::Constants::ICN', 'ICN')

      allow(MPI::Service).to receive(:new).and_return(mpi_service)
      allow(mpi_service).to receive(:find_profile_by_identifier)
        .with(hash_including(identifier: user.user_account.icn, identifier_type: 'ICN'))
        .and_return(mpi_resp)

      allow(DebtsApi::V0::DigitalDisputeSubmission).to receive(:find)
        .with(submission.id).and_return(submission)
    end

    context 'success' do
      it 'builds the DMC service with MPI user, calls it, marks success, and clears the in-progress form' do
        service = instance_double(DebtsApi::V0::DigitalDisputeDmcService, call!: true)
        expect(DebtsApi::V0::DigitalDisputeDmcService).to receive(:new)
          .with(have_attributes(participant_id: user.participant_id, ssn: user.ssn), submission)
          .and_return(service)

        form_double = instance_double(InProgressForm, destroy: true)
        expect(InProgressForm).to receive(:find_by)
          .with(form_id: 'DISPUTE-DEBT', user_uuid: submission.user_uuid)
          .and_return(form_double)

        expect(submission).to receive(:register_success)

        described_class.new.perform(submission.id)
      end
    end

    context 'when the DMC service raises' do
      it 'logs and re-raises; does not mark success' do
        service = instance_double(DebtsApi::V0::DigitalDisputeDmcService)
        allow(DebtsApi::V0::DigitalDisputeDmcService).to receive(:new).and_return(service)
        allow(service).to receive(:call!).and_raise(StandardError, 'boom')

        expect(Rails.logger).to receive(:error)
          .with(a_string_matching(/DigitalDisputeJob failed for submission_id #{submission.id}: boom/))
        expect(submission).not_to receive(:register_success)

        expect { described_class.new.perform(submission.id) }
          .to raise_error(StandardError, 'boom')
      end
    end

    context 'when no in-progress form exists' do
      it 'still marks success' do
        service = instance_double(DebtsApi::V0::DigitalDisputeDmcService, call!: true)
        expect(DebtsApi::V0::DigitalDisputeDmcService).to receive(:new)
          .with(have_attributes(participant_id: user.participant_id, ssn: user.ssn), submission)
          .and_return(service)

        expect(InProgressForm).to receive(:find_by)
          .with(form_id: 'DISPUTE-DEBT', user_uuid: submission.user_uuid)
          .and_return(nil)

        expect(submission).to receive(:register_success)

        described_class.new.perform(submission.id)
      end
    end
  end

  describe 'sidekiq_retries_exhausted hook' do
    let(:config) { described_class }

    let(:user) { create(:user, :loa3) }
    let!(:submission) do
      create(:debts_api_digital_dispute_submission,
             user_uuid: user.uuid,
             user_account: user.user_account,
             state: :pending)
    end

    let(:msg) { { 'class' => config.name, 'args' => [submission.id], 'jid' => 'abc123', 'retry_count' => 25 } }

    let(:ex) do
      e = StandardError.new('kaput')
      allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
      e
    end

    it 'increments StatsD, registers failure, and logs details' do
      expected_log = <<~LOG
        V0::DigitalDisputeJob retries exhausted:
        submission_id: #{submission.id}
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG

      # StatsD key used by the job
      stub_const('DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY', 'debts_api.v0.digital_dispute')
      expect(StatsD).to receive(:increment).with('debts_api.v0.digital_dispute.retries_exhausted')

      # Let the hook load the record for real, but assert failure handling on it
      expect(DebtsApi::V0::DigitalDisputeSubmission).to receive(:find).with(submission.id).and_call_original
      expect_any_instance_of(DebtsApi::V0::DigitalDisputeSubmission)
        .to receive(:register_failure).with('DigitalDisputeJob#perform: kaput')

      expect(Rails.logger).to receive(:error).with(expected_log)

      # Call the hook directly, like your other job spec
      config.sidekiq_retries_exhausted_block.call(msg, ex)
    end
  end
end
