# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'dependents_benefits/monitor'
require 'dependents_benefits/notification_email'
require 'sidekiq/job_retry'

RSpec.describe DependentsBenefits::Sidekiq::DependentSubmissionJob, type: :job do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('/tmp/dummy.pdf')
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
    allow(DependentsBenefits::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_submission_info)
    allow(monitor).to receive(:track_submission_error)
    allow(DependentsBenefits::ClaimProcessor).to receive(:new).and_return(claim_processor)
    allow(claim_processor).to receive(:collect_child_claims).and_return([child_claim])
    allow(claim_processor).to receive(:handle_successful_submission)
    allow(claim_processor).to receive(:handle_permanent_failure)
  end

  let(:saved_claim) { create(:dependents_claim) }
  let(:claim_id) { saved_claim.id }
  let(:job) { described_class.new }
  let(:parent_claim) { create(:dependents_claim) }
  let(:child_claim) { create(:add_remove_dependents_claim) }
  let(:sibling_claim) { create(:student_claim) }
  let(:failed_response) { double('ServiceResponse', success?: false, error: 'Service unavailable') }
  let(:successful_response) { double('ServiceResponse', success?: true) }
  let(:monitor) { instance_double(DependentsBenefits::Monitor) }
  let(:claim_processor) { instance_double(DependentsBenefits::ClaimProcessor) }

  describe '#perform' do
    context 'when claim group has already failed' do
      let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:, status: SavedClaimGroup::STATUSES[:FAILURE]) }
      let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }

      it 'skips submission without creating form submission attempt' do
        expect(job).not_to receive(:submit_claims_to_service)
        job.perform(parent_claim.id)
      end
    end

    it 'assigns claim_id from perform arguments' do
      create(:parent_claim_group, parent_claim:)
      create(:saved_claim_group, saved_claim: child_claim, parent_claim:)

      allow(job).to receive(:submit_claims_to_service).and_return(successful_response)
      allow(job).to receive(:handle_job_success)

      job.perform(parent_claim.id)

      expect(job.instance_variable_get(:@claim_id)).to eq(parent_claim.id)
    end

    context 'when all validations pass' do
      before do
        allow(job).to receive(:submit_claims_to_service).and_return(successful_response)
        allow(job).to receive(:handle_job_success)
      end

      it 'follows expected execution order' do
        create(:parent_claim_group, parent_claim:)
        create(:saved_claim_group, saved_claim: child_claim, parent_claim:)
        expect(job).to receive(:submit_claims_to_service).ordered
        expect(job).to receive(:handle_job_success).ordered

        job.perform(parent_claim.id)
      end
    end

    context 'with claim groups' do
      let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
      let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }

      it 'skips processing if the parent group failed' do
        parent_claim_group.update!(status: SavedClaimGroup::STATUSES[:FAILURE])
        expect(job).not_to receive(:submit_claims_to_service)
        job.perform(parent_claim.id)
      end

      it 'handles successful submissions' do
        allow(job).to receive(:submit_claims_to_service).and_return(successful_response)
        expect(job).to receive(:handle_job_success)
        job.perform(parent_claim.id)
      end

      it 'handles failed submissions when submit_claims_to_service raises error' do
        error = DependentsBenefits::Sidekiq::DependentSubmissionError.new('Service failed')
        allow(job).to receive(:submit_claims_to_service).and_raise(error)
        expect(job).to receive(:handle_job_failure).with(error)
        job.perform(parent_claim.id)
      end

      it 'handles errors' do
        error = StandardError.new('Unexpected error')
        allow(job).to receive(:submit_claims_to_service).and_raise(error)
        expect(job).to receive(:handle_job_failure).with(error)
        job.perform(parent_claim.id)
      end
    end
  end

  describe 'exception handling' do
    context 'when submit_claims_to_service raises exception with message' do
      let(:exception) { StandardError.new('BGS Error: SSN 123-45-6789 invalid') }
      let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
      let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }

      before do
        allow(job).to receive(:submit_claims_to_service).and_raise(exception)
      end

      it 'passes exception object to handle_job_failure, not string' do
        expect(job).to receive(:handle_job_failure).with(exception)
        job.perform(parent_claim.id)
      end
    end
  end

  describe 'sidekiq_retries_exhausted callback' do
    it 'calls handle_permanent_failure' do
      msg = { 'args' => [parent_claim.id], 'class' => described_class.name }
      exception = StandardError.new('Service failed')

      expect_any_instance_of(described_class).to receive(:handle_permanent_failure)
        .with(parent_claim.id, exception)

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
    context 'when submit_claims_to_service raises unexpected error' do
      let(:timeout_error) { Timeout::Error.new }
      let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
      let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }

      before do
        allow(job).to receive(:submit_claims_to_service).and_raise(timeout_error)
      end

      it 'catches and handles timeout errors' do
        expect(job).to receive(:handle_job_failure).with(timeout_error)
        job.perform(parent_claim.id)
      end
    end
  end

  describe 'abstract method enforcement' do
    it 'raises NotImplementedError for submit_claims_to_service' do
      expect do
        job.send(:submit_claims_to_service)
      end.to raise_error(NotImplementedError, 'Subclasses must implement submit_claims_to_service method')
    end

    it 'raises NotImplementedError for submit_686c_form' do
      expect do
        job.send(:submit_686c_form, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement submit_686c_form method')
    end

    it 'raises NotImplementedError for submit_674_form' do
      expect do
        job.send(:submit_674_form, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement submit_674_form method')
    end

    it 'raises NotImplementedError for submission_previously_succeeded?' do
      expect do
        job.send(:submission_previously_succeeded?, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement submission_previously_succeeded?')
    end

    it 'raises NotImplementedError for find_or_create_form_submission' do
      expect do
        job.send(:find_or_create_form_submission, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement find_or_create_form_submission')
    end

    it 'raises NotImplementedError for create_form_submission_attempt' do
      expect do
        job.send(:create_form_submission_attempt, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement create_form_submission_attempt')
    end

    it 'raises NotImplementedError for mark_submission_attempt_succeeded' do
      expect do
        job.send(:mark_submission_attempt_succeeded, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement mark_submission_attempt_succeeded')
    end

    it 'raises NotImplementedError for mark_submission_attempt_failed' do
      expect do
        job.send(:mark_submission_attempt_failed, nil, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement mark_submission_attempt_failed')
    end
  end

  describe '#handle_job_success' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }

    before do
      allow(job).to receive(:parent_claim_id).and_return(parent_claim.id)
    end

    it 'delegates to claim_processor' do
      expect(claim_processor).to receive(:handle_successful_submission)
      job.send(:handle_job_success)
    end

    it 'logs submission info' do
      expect(monitor).to receive(:track_submission_info).with(
        match(/Successfully submitted/),
        'success',
        parent_claim_id: parent_claim.id
      )
      job.send(:handle_job_success)
    end
  end

  describe '#handle_job_failure' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }

    before do
      job.instance_variable_set(:@claim_id, parent_claim.id)
    end

    context 'when the failure is permanent' do
      let(:error) { StandardError.new('Service destroyed') }

      before do
        allow(job).to receive(:permanent_failure?).and_return(true)
      end

      it 'calls handle_permanent_failure and skips retry' do
        expect(job).to receive(:handle_permanent_failure).with(parent_claim.id, error)
        expect { job.send(:handle_job_failure, error) }.to raise_error(Sidekiq::JobRetry::Skip)
      end
    end

    context 'when the failure is transient' do
      let(:error) { StandardError.new('Service unavailable') }

      before do
        allow(job).to receive(:permanent_failure?).and_return(false)
      end

      it 'raises DependentSubmissionError to trigger retry' do
        expect { job.send(:handle_job_failure, error) }.to raise_error(
          DependentsBenefits::Sidekiq::DependentSubmissionError,
          error.message
        )
      end
    end
  end

  describe '#handle_permanent_failure' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
    let(:exception) { StandardError.new('Service destroyed') }

    before do
      allow(job).to receive(:parent_claim_id).and_return(parent_claim.id)
    end

    it 'delegates to claim_processor' do
      expect(claim_processor).to receive(:handle_permanent_failure).with(exception)
      job.send(:handle_permanent_failure, parent_claim.id, exception)
    end

    it 'logs the permanent failure' do
      expect(monitor).to receive(:track_submission_error).with(
        match(/Error submitting/),
        'error.permanent',
        error: exception,
        parent_claim_id: parent_claim.id,
        claim_id: parent_claim.id
      )
      job.send(:handle_permanent_failure, parent_claim.id, exception)
    end
  end

  describe '#sidekiq_retries_exhausted' do
    it 'handles retries exhausted with parent_claim_id' do
      described_class.within_sidekiq_retries_exhausted_block(
        { 'args' => [parent_claim.id], 'class' => described_class.name }, 'Failure!'
      ) do
        allow(described_class).to receive(:new).and_return(job)
        expect(job).to receive(:handle_permanent_failure).with(parent_claim.id, 'Failure!')
      end
    end
  end
end
