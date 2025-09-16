# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_dmc_service'

RSpec.describe DebtsApi::V0::DigitalDisputeJob, type: :worker do
  subject(:worker) { described_class.new }

  let(:submission_id) { 123 }
  let(:user_account)  { instance_double(UserAccount, icn: '1000123456V123456') }
  let(:submission)    { instance_double(DebtsApi::V0::DigitalDisputeSubmission, user_account:) }

  let(:mpi_profile)   { instance_double(MPI::Models::MviProfile, participant_id: '1234567', ssn: '111223333') }
  let(:mpi_response)  { instance_double(MPI::Responses::FindProfileResponse, profile: mpi_profile) }

  let(:service_double)   { instance_double(DebtsApi::V0::DigitalDisputeDmcService) }
  let(:in_progress_form) { instance_double(InProgressForm) }

  before do
    # Submission lookup shared by examples
    allow(DebtsApi::V0::DigitalDisputeSubmission).to receive(:find).with(submission_id).and_return(submission)

    # Submission hooks used in multiple paths
    allow(submission).to receive(:register_success)
    allow(submission).to receive(:register_failure)
  end

  describe '#perform' do
    before do
      stub_const('MPI::Constants::ICN', 'ICN')

      allow(MPI::Service).to receive(:new).and_return(
        instance_double(MPI::Service, find_profile_by_identifier: mpi_response)
      )

      allow(DebtsApi::V0::DigitalDisputeDmcService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call!)

      # Define current_user on the subject (not an RSpec stub) to satisfy the helper
      worker.define_singleton_method(:current_user) { Object.new }

      # Stub collaborator instead of stubbing the subject (#in_progress_form)
      allow(InProgressForm).to receive(:form_for_user)
        .with('DISPUTE-DEBT', anything)
        .and_return(in_progress_form)
      allow(in_progress_form).to receive(:destroy)
    end

    it 'processes the submission via call!, marks success, and clears in-progress form' do
      worker.perform(submission_id)

      expect(DebtsApi::V0::DigitalDisputeDmcService).to have_received(:new) do |user, given_submission|
        expect(given_submission).to eq(submission)
        expect(user.participant_id).to eq('1234567')
        expect(user.ssn).to eq('111223333')
      end

      expect(service_double).to have_received(:call!)
      expect(submission).to have_received(:register_success)
      expect(in_progress_form).to have_received(:destroy)
      expect(InProgressForm).to have_received(:form_for_user).with('DISPUTE-DEBT', anything)
    end

    it 're-raises on failure from call! and logs an error' do
      allow(service_double).to receive(:call!).and_raise(StandardError, 'boom')
      logger = double('Logger').as_null_object
      allow(Rails).to receive(:logger).and_return(logger)

      expect { worker.perform(submission_id) }.to raise_error(StandardError, 'boom')

      expect(submission).not_to have_received(:register_success)
      expect(logger).to have_received(:error).with(
        /DigitalDisputeJob failed for submission_id #{submission_id}: boom/
      )
    end

    it 'does nothing if in_progress_form is nil' do
      # Keep current_user defined on the instance
      worker.define_singleton_method(:current_user) { Object.new }
      allow(InProgressForm).to receive(:form_for_user).and_return(nil)

      expect { worker.perform(submission_id) }.not_to raise_error
      expect(submission).to have_received(:register_success)
    end
  end

  describe 'sidekiq_retries_exhausted hook' do
    it 'increments StatsD with the submission stats key, registers failure, and logs' do
      # Cross-version retrieval of the configured exhausted block
      exhausted_proc =
        if described_class.respond_to?(:sidekiq_retries_exhausted_block)
          described_class.sidekiq_retries_exhausted_block
        elsif described_class.respond_to?(:get_sidekiq_options)
          described_class.get_sidekiq_options['retries_exhausted'] ||
            described_class.get_sidekiq_options[:retries_exhausted]
        else
          opts = described_class.sidekiq_options
          opts['retries_exhausted'] || opts[:retries_exhausted]
        end

      expect(exhausted_proc).to be_a(Proc)

      stub_const('DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY', 'debts_api.v0.digital_dispute')
      allow(StatsD).to receive(:increment)

      logger = double('Logger').as_null_object
      allow(Rails).to receive(:logger).and_return(logger)

      ex = StandardError.new('kaput')
      allow(ex).to receive(:backtrace).and_return(%w[line1 line2])

      job_hash = { 'args' => [submission_id] }

      exhausted_proc.call(job_hash, ex)

      expect(StatsD).to have_received(:increment).with('debts_api.v0.digital_dispute.retries_exhausted')
      expect(submission).to have_received(:register_failure).with('VBASubmissionJob#perform: kaput')
      expect(logger).to have_received(:error).with(a_string_matching(/V0::DigitalDisputeJob retries exhausted:/))
    end
  end
end
