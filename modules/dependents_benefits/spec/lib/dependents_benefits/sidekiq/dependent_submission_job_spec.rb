# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/dependent_submission_job'

RSpec.describe DependentsBenefits::DependentSubmissionJob, type: :job do
  let(:claim_id) { saved_claim.id }
  let(:proc_id) { 'test-proc-123' }
  let(:saved_claim) { create(:dependents_claim) }
  let(:job) { described_class.new }

  before do
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  describe '#perform' do
    context 'when claim group has already failed' do
      before do
        allow(job).to receive(:claim_group_failed?).and_return(true)
      end

      it 'skips submission without creating form submission attempt' do
        expect(job).not_to receive(:submit_to_service)
        job.perform(claim_id, proc_id)
      end
    end

    it 'assigns claim_id and proc_id from perform arguments' do
      allow(job).to receive(:claim_group_failed?).and_return(true)

      job.perform(claim_id, proc_id)

      expect(job.instance_variable_get(:@claim_id)).to eq(claim_id)
      expect(job.instance_variable_get(:@proc_id)).to eq(proc_id)
    end

    context 'when all validations pass' do
      let(:mock_response) { double('ServiceResponse', success?: true) }

      before do
        allow(job).to receive_messages(claim_group_failed?: false, submit_to_service: mock_response)
        allow(job).to receive(:create_form_submission_attempt)
        allow(job).to receive(:handle_job_success)
      end

      it 'follows expected execution order' do
        expect(job).to receive(:claim_group_failed?).ordered
        expect(job).to receive(:create_form_submission_attempt).ordered
        expect(job).to receive(:submit_to_service).ordered
        expect(job).to receive(:handle_job_success).ordered

        job.perform(claim_id, proc_id)
      end
    end
  end

  describe 'exception handling' do
    context 'when submit_to_service raises exception with message' do
      let(:exception) { StandardError.new('BGS Error: SSN 123-45-6789 invalid') }

      before do
        allow(job).to receive(:claim_group_failed?).and_return(false)
        allow(job).to receive(:create_form_submission_attempt)
        allow(job).to receive(:submit_to_service).and_raise(exception)
      end

      it 'passes exception object to handle_job_failure, not string' do
        expect(job).to receive(:handle_job_failure).with(exception)
        job.perform(claim_id, proc_id)
      end
    end
  end

  describe 'query methods' do
    describe '#claim_group_failed?' do
      it 'returns false by default' do
        expect(job.send(:claim_group_failed?)).to be false
      end
    end

    describe '#claim_group_completed?' do
      it 'returns false by default' do
        expect(job.send(:claim_group_completed?)).to be false
      end
    end
  end

  describe 'sidekiq_retries_exhausted callback' do
    it 'calls handle_permanent_failure' do
      msg = { 'args' => [claim_id, proc_id] }
      exception = StandardError.new('Service failed')

      expect_any_instance_of(described_class).to receive(:handle_permanent_failure)
        .with(claim_id, exception)

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end

  describe '#permanent_failure?' do
    it 'returns false for nil error' do
      expect(job.send(:permanent_failure?, nil)).to be false
    end

    it 'returns false for any error by default' do
      expect(job.send(:permanent_failure?, 'Some error')).to be false
    end
  end

  describe 'error handling edge cases' do
    context 'when create_form_submission_attempt fails' do
      before do
        allow(job).to receive(:claim_group_failed?).and_return(false)
        allow(job).to receive(:create_form_submission_attempt).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'handles creation failure gracefully' do
        expect(job).to receive(:handle_job_failure)
        job.perform(claim_id, proc_id)
      end
    end

    context 'when submit_to_service raises unexpected error' do
      let(:timeout_error) { Timeout::Error.new }

      before do
        allow(job).to receive(:claim_group_failed?).and_return(false)
        allow(job).to receive(:create_form_submission_attempt)
        allow(job).to receive(:submit_to_service).and_raise(timeout_error)
      end

      it 'catches and handles timeout errors' do
        expect(job).to receive(:handle_job_failure).with(timeout_error)
        job.perform(claim_id, proc_id)
      end
    end
  end

  describe 'abstract method enforcement' do
    it 'raises NotImplementedError for submit_to_service' do
      expect do
        job.send(:submit_to_service)
      end.to raise_error(NotImplementedError, 'Subclasses must implement submit_to_service')
    end

    it 'raises NotImplementedError for find_or_create_form_submission' do
      expect do
        job.send(:find_or_create_form_submission)
      end.to raise_error(NotImplementedError, 'Subclasses must implement find_or_create_form_submission')
    end

    it 'raises NotImplementedError for create_form_submission_attempt' do
      expect do
        job.send(:create_form_submission_attempt)
      end.to raise_error(NotImplementedError, 'Subclasses must implement create_form_submission_attempt')
    end
  end
end
