# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/dependent_submission_job'

##
# Fake submission job for testing DependentSubmissionJob behavior
# Allows testing success/failure paths without external service dependencies
class FakeSubmissionJob < DependentsBenefits::DependentSubmissionJob
  attr_accessor :response_behavior, :should_raise_error

  def initialize
    super
    @response_behavior = :success
    @should_raise_error = false
  end

  def submit_to_service
    raise StandardError, 'Simulated service error' if should_raise_error

    case response_behavior
    when :success
      ServiceResponse.new(success: true, data: { confirmation_id: '12345' })
    when :failure
      ServiceResponse.new(success: false, error: 'Service unavailable')
    when :timeout
      raise Timeout::Error, 'Service timeout'
    else
      ServiceResponse.new(success: true)
    end
  end
end

##
# Mock ServiceResponse for testing
ServiceResponse = Struct.new(:success, :data, :error, keyword_init: true) do
  def success? = success
end

RSpec.describe DependentsBenefits::DependentSubmissionJob, type: :job do
  let(:claim_id) { saved_claim.id }
  let(:proc_id) { 'test-proc-123' }
  let(:saved_claim) { create(:dependents_claim) }

  let(:job) { FakeSubmissionJob.new }

  before do
    job.response_behavior = :success
    job.should_raise_error = false
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

    context 'when submission succeeds' do
      it 'handles job success' do
        expect(job).to receive(:handle_job_success)
        job.perform(claim_id, proc_id)
      end
    end

    context 'when submission fails' do
      before do
        job.response_behavior = :failure
      end

      it 'handles job failure with error message' do
        expect(job).to receive(:handle_job_failure).with('Service unavailable')
        job.perform(claim_id, proc_id)
      end
    end

    context 'when service times out' do
      before do
        job.response_behavior = :timeout
      end

      it 'handles timeout error' do
        expect(job).to receive(:handle_job_failure)
        expect { job.perform(claim_id, proc_id) }.not_to raise_error
      end
    end
  end

  describe 'sidekiq_retries_exhausted callback' do
    it 'calls handle_permanent_failure' do
      msg = { 'args' => [claim_id, proc_id] }
      exception = StandardError.new('Service failed')

      expect_any_instance_of(described_class).to receive(:handle_permanent_failure)
        .with(claim_id, proc_id, exception)

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end

  describe '#handle_job_success' do
    let(:form_submission) { create(:form_submission) }
    let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

    before do
      # Set up instance variables as if perform was called
      job.instance_variable_set(:@claim_id, claim_id)
      job.instance_variable_set(:@proc_id, proc_id)
      job.instance_variable_set(:@form_submission_attempt, form_submission_attempt)

      # Mock the dependencies
      allow(job).to receive_messages(
        form_submission:
      )
    end

    it 'updates form submission attempt status to success using AASM' do
      expect(form_submission_attempt).to receive(:succeed!)

      job.send(:handle_job_success)
    end

    it 'wraps all updates in a database transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield

      allow(form_submission_attempt).to receive(:succeed!)

      job.send(:handle_job_success)
    end

    context 'when database update fails' do
      it 'rolls back all changes' do
        allow(form_submission_attempt).to receive(:succeed!).and_raise(ActiveRecord::RecordInvalid)

        expect { job.send(:handle_job_success) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#handle_permanent_failure' do
    let(:exception) { StandardError.new('BGS service permanently unavailable') }
    let(:form_submission_attempt) { double('FormSubmissionAttempt') }
    let(:form_submission) { double('FormSubmission') }
    let(:monitor) { double('Monitor') }

    before do
      # Mock dependencies
      allow(job).to receive_messages(form_submission:,
                                     monitor:)
      # Set up form submission attempt
      job.instance_variable_set(:@form_submission_attempt, form_submission_attempt)
    end

    it 'sets claim_id and proc_id instance variables' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      allow(job).to receive(:mark_submission_records_failed)
      allow(job).to receive(:mark_claim_groups_failed)
      allow(monitor).to receive(:log_permanent_failure)

      job.send(:handle_permanent_failure, claim_id, proc_id, exception)

      expect(job.instance_variable_get(:@claim_id)).to eq(claim_id)
      expect(job.instance_variable_get(:@proc_id)).to eq(proc_id)
    end

    it 'wraps all operations in a database transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield
      allow(job).to receive(:mark_submission_records_failed)
      allow(job).to receive(:mark_claim_groups_failed)
      allow(monitor).to receive(:log_permanent_failure)

      job.send(:handle_permanent_failure, claim_id, proc_id, exception)
    end

    it 'marks submission records as failed' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      expect(job).to receive(:mark_submission_records_failed).with(exception)
      allow(job).to receive(:mark_claim_groups_failed)
      allow(monitor).to receive(:log_permanent_failure)

      job.send(:handle_permanent_failure, claim_id, proc_id, exception)
    end

    it 'marks claim groups as failed' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      allow(job).to receive(:mark_submission_records_failed)
      expect(job).to receive(:mark_claim_groups_failed)
      allow(monitor).to receive(:log_permanent_failure)

      job.send(:handle_permanent_failure, claim_id, proc_id, exception)
    end

    it 'logs permanent failure to monitoring' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      allow(job).to receive(:mark_submission_records_failed)
      allow(job).to receive(:mark_claim_groups_failed)
      expect(monitor).to receive(:log_permanent_failure)

      job.send(:handle_permanent_failure, claim_id, proc_id, exception)
    end

    context 'when database operations fail' do
      it 'logs silent failure and does not re-raise' do
        allow(ActiveRecord::Base).to receive(:transaction).and_raise(ActiveRecord::RecordInvalid)
        expect(monitor).to receive(:log_silent_failure)

        expect { job.send(:handle_permanent_failure, claim_id, proc_id, exception) }.not_to raise_error
      end
    end

    context 'when monitoring fails' do
      it 'logs silent failure and does not re-raise' do
        allow(ActiveRecord::Base).to receive(:transaction).and_yield
        allow(job).to receive(:mark_submission_records_failed)
        allow(job).to receive(:mark_claim_groups_failed)
        allow(monitor).to receive(:log_permanent_failure).and_raise(StandardError)
        expect(monitor).to receive(:log_silent_failure)

        expect { job.send(:handle_permanent_failure, claim_id, proc_id, exception) }.not_to raise_error
      end
    end

    describe '#mark_submission_records_failed' do
      context 'when form submission attempt exists' do
        it 'updates form submission attempt with failure details using AASM' do
          expect(form_submission_attempt).to receive(:update!).with(
            error_message: "Job exhausted after retries: #{exception.message}"
          )
          expect(form_submission_attempt).to receive(:fail!)

          job.send(:mark_submission_records_failed, exception)
        end
      end

      context 'when form submission attempt is nil' do
        before do
          job.instance_variable_set(:@form_submission_attempt, nil)
        end

        it 'does not attempt to update submission attempt' do
          expect(form_submission_attempt).not_to receive(:update!)
          expect(form_submission_attempt).not_to receive(:fail!)

          job.send(:mark_submission_records_failed, exception)
        end
      end
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

  describe '#handle_job_failure' do
    let(:form_submission_attempt) { double('FormSubmissionAttempt') }
    let(:error_message) { 'BGS service unavailable' }

    context 'when form submission attempt exists' do
      before do
        job.instance_variable_set(:@form_submission_attempt, form_submission_attempt)
        job.instance_variable_set(:@claim_id, claim_id)
        job.instance_variable_set(:@proc_id, proc_id)
        allow(job).to receive(:permanent_failure?).and_return(false)
      end

      it 'updates attempt with error message and transitions to failed state' do
        expect(form_submission_attempt).to receive(:update!).with(error_message:)
        expect(form_submission_attempt).to receive(:fail!)

        expect { job.send(:handle_job_failure, error_message) }.to raise_error(error_message)
      end
    end

    context 'when form submission attempt is nil' do
      let(:new_attempt) { double('FormSubmissionAttempt') }

      before do
        job.instance_variable_set(:@form_submission_attempt, nil)
        job.instance_variable_set(:@claim_id, claim_id)
        job.instance_variable_set(:@proc_id, proc_id)
        allow(job).to receive(:permanent_failure?).and_return(false)
      end

      it 'creates new form submission attempt to track the failure' do
        expect(job).to receive(:create_form_submission_attempt).and_return(new_attempt)
        expect(new_attempt).to receive(:update!).with(error_message:)
        expect(new_attempt).to receive(:fail!)

        expect { job.send(:handle_job_failure, error_message) }.to raise_error(error_message)
      end
    end

    context 'when failure is permanent' do
      before do
        job.instance_variable_set(:@form_submission_attempt, form_submission_attempt)
        job.instance_variable_set(:@claim_id, claim_id)
        job.instance_variable_set(:@proc_id, proc_id)
        allow(job).to receive(:permanent_failure?).and_return(true)
        allow(job).to receive(:handle_permanent_failure)
      end

      it 'calls handle_permanent_failure and raises Skip' do
        allow(form_submission_attempt).to receive(:update!)
        allow(form_submission_attempt).to receive(:fail!)

        expect(job).to receive(:handle_permanent_failure).with(claim_id, proc_id, error_message)

        stub_const('Sidekiq::JobRetry::Skip', Class.new(StandardError))
        expect { job.send(:handle_job_failure, error_message) }.to raise_error(Sidekiq::JobRetry::Skip)
      end
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
      before do
        allow(job).to receive(:claim_group_failed?).and_return(false)
        allow(job).to receive(:create_form_submission_attempt)
        # Use Timeout::Error instead of Net::TimeoutError
        allow(job).to receive(:submit_to_service).and_raise(Timeout::Error)
      end

      it 'catches and handles timeout errors' do
        expect(job).to receive(:handle_job_failure).with('Timeout::Error')
        job.perform(claim_id, proc_id)
      end
    end
  end

  describe 'full job execution flow' do
    let(:saved_claim) { create(:dependents_claim) }
    let(:claim_id) { saved_claim.id }

    before do
      # Mock all external dependencies
      allow(job).to receive(:claim_group_failed?).and_return(false)
      allow(job).to receive(:create_form_submission_attempt)
      allow(job).to receive(:handle_job_success)
      allow(job).to receive(:handle_job_failure)
    end

    it 'executes complete success flow' do
      job.response_behavior = :success

      expect(job).to receive(:create_form_submission_attempt).ordered
      expect(job).to receive(:submit_to_service).and_call_original.ordered
      expect(job).to receive(:handle_job_success).ordered

      job.perform(claim_id, proc_id)
    end

    it 'executes complete failure flow' do
      job.response_behavior = :failure

      expect(job).to receive(:create_form_submission_attempt).ordered
      expect(job).to receive(:submit_to_service).and_call_original.ordered
      expect(job).to receive(:handle_job_failure).with('Service unavailable').ordered

      job.perform(claim_id, proc_id)
    end
  end

  describe 'abstract method enforcement' do
    let(:base_job) { described_class.new }

    it 'raises NotImplementedError for submit_to_service' do
      expect do
        base_job.send(:submit_to_service)
      end.to raise_error(NotImplementedError, 'Subclasses must implement submit_to_service')
    end
  end

  describe 'atomicity and race conditions' do
    describe '#handle_job_success transaction atomicity' do
      let(:form_submission) { create(:form_submission) }

      before do
        job.instance_variable_set(:@claim_id, claim_id)
        job.instance_variable_set(:@proc_id, proc_id)
        allow(job).to receive_messages(
          form_submission:
        )
      end

      context 'transaction rollback scenarios' do
        it 'rolls back all updates when any operation fails' do
          form_submission_attempt = create(:form_submission_attempt, form_submission:)
          job.instance_variable_set(:@form_submission_attempt, form_submission_attempt)

          # Test form submission attempt failure scenario
          allow(form_submission_attempt).to receive(:succeed!).and_raise(ActiveRecord::RecordInvalid)

          expect { job.send(:handle_job_success) }.to raise_error(ActiveRecord::RecordInvalid)
          expect(form_submission_attempt.reload.aasm_state).not_to eq('success')
        end
      end
    end
  end
end
