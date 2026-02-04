# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'dependents_benefits/monitor'
require 'dependents_benefits/notification_email'
require 'dependents_benefits'
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
    context 'on successful exhaustion' do
      it 'calls handle_permanent_failure' do
        msg = { 'args' => [parent_claim.id], 'class' => described_class.name }
        exception = StandardError.new('Service failed')

        expect_any_instance_of(described_class).to receive(:handle_permanent_failure)
          .with(parent_claim.id, exception)

        described_class.sidekiq_retries_exhausted_block.call(msg, exception)
      end
    end

    context 'on failed exhaustion' do
      it 'logs silent failure if the class name is missing' do
        msg = { 'args' => [parent_claim.id] }
        exception = StandardError.new('Service failed')

        expect(monitor).to receive(:log_silent_failure).with({
                                                               claim_id: parent_claim.id,
                                                               error: exception
                                                             })

        expect_any_instance_of(DependentsBenefits::Sidekiq::DependentSubmissionJob)
          .not_to receive(:handle_permanent_failure)

        described_class.sidekiq_retries_exhausted_block.call(msg, exception)
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

    it 'raises NotImplementedError for mark_submission_failed' do
      expect do
        job.send(:mark_submission_failed, nil)
      end.to raise_error(NotImplementedError, 'Subclasses must implement mark_submission_failed')
    end
  end

  describe '#child_claims' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
    let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }
    let!(:sibling_claim_group) { create(:saved_claim_group, saved_claim: sibling_claim, parent_claim:) }

    it 'returns child claims from claim_processor' do
      allow(job).to receive(:parent_claim_id).and_return(parent_claim.id)
      expect(claim_processor).to receive(:collect_child_claims).and_return([child_claim, sibling_claim])
      result = job.send(:child_claims)
      expect(result).to contain_exactly(child_claim, sibling_claim)
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

    it 'tracks submission error on error' do
      allow(claim_processor).to receive(:handle_successful_submission).and_raise(StandardError.new('Logging error'))
      expect(monitor).to receive(:track_submission_error).with(
        'Error handling job success',
        'success_failure',
        error: anything,
        claim_id: anything,
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

    context 'when handle permanent failure raises error' do
      let(:email_double) { instance_double(DependentsBenefits::NotificationEmail) }

      before do
        allow(DependentsBenefits::NotificationEmail).to receive(:new).and_return(email_double)
        allow(email_double).to receive(:send_error_notification)
      end

      context 'when sending an error email succeeds' do
        it 'sends the email and logs silent failure avoided' do
          allow(monitor).to receive(:log_silent_failure_avoided)
          allow(claim_processor).to receive(:handle_permanent_failure).and_raise(StandardError.new('failed'))
          expect(email_double).to receive(:send_error_notification)
          expect(monitor).to receive(:log_silent_failure_avoided).with({
                                                                         claim_id: parent_claim.id,
                                                                         error: anything
                                                                       })
          job.send(:handle_permanent_failure, parent_claim.id, exception)
        end
      end

      context 'when sending an error email fails' do
        before do
          allow(monitor).to receive(:log_silent_failure)
          allow(email_double).to receive(:send_error_notification).and_raise(StandardError.new('email error'))
          allow(claim_processor).to receive(:handle_permanent_failure).and_raise(StandardError.new('failed'))
        end

        it 'logs the email sending error' do
          expect(monitor).to receive(:log_silent_failure).with({
                                                                 claim_id: parent_claim.id,
                                                                 error: anything
                                                               })
          job.send(:handle_permanent_failure, parent_claim.id, exception)
        end
      end
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

  describe '#submit_claim_to_service' do
    let(:claim) { create(:add_remove_dependents_claim) }
    let(:submission) { double('FormSubmission') }
    let(:submission_attempt) { double('FormSubmissionAttempt') }
    let(:user_data_hash) { { 'veteran_information' => { 'ssn' => '123456789' } } }

    before do
      allow(job).to receive(:find_or_create_form_submission).with(claim).and_return(submission)
      allow(job).to receive(:create_form_submission_attempt).with(submission).and_return(submission_attempt)
      allow(job).to receive(:mark_submission_attempt_succeeded).with(submission_attempt)
      allow(job).to receive(:mark_submission_attempt_failed)
      allow(job).to receive_messages(
        user_data: user_data_hash,
        mark_submission_attempt_failed: nil,
        mark_submission_failed: nil,
        parent_claim_id: parent_claim.id
      )
      allow(claim).to receive(:add_veteran_info).with(user_data_hash)
    end

    context 'when submission previously succeeded' do
      before do
        allow(job).to receive(:submission_previously_succeeded?).with(submission).and_return(true)
      end

      it 'returns successful response without further processing' do
        expect(job).not_to receive(:create_form_submission_attempt)
        expect(job).not_to receive(:submit_686c_form)
        expect(job).not_to receive(:submit_674_form)

        result = job.send(:submit_claim_to_service, claim)

        expect(result.status).to be true
        expect(result.success?).to be true
      end
    end

    context 'when submission has not previously succeeded' do
      before do
        allow(job).to receive(:submission_previously_succeeded?).with(submission).and_return(false)
      end

      context 'when claim is ADD_REMOVE_DEPENDENT (686c) form' do
        before do
          allow(claim).to receive(:form_id).and_return(DependentsBenefits::ADD_REMOVE_DEPENDENT)
        end

        context 'when claim is valid' do
          before do
            allow(claim).to receive(:valid?).with(:run_686_form_jobs).and_return(true)
            allow(job).to receive(:submit_686c_form).with(claim)
          end

          it 'processes the 686c form successfully' do
            expect(job).to receive(:submit_686c_form).with(claim)
            expect(job).to receive(:mark_submission_attempt_succeeded).with(submission_attempt)

            result = job.send(:submit_claim_to_service, claim)

            expect(result.status).to be true
            expect(result.success?).to be true
          end

          it 'adds veteran info to claim before submission' do
            expect(claim).to receive(:add_veteran_info).with(user_data_hash)
            job.send(:submit_claim_to_service, claim)
          end

          it 'validates claim with run_686_form_jobs context' do
            expect(claim).to receive(:valid?).with(:run_686_form_jobs)
            job.send(:submit_claim_to_service, claim)
          end
        end

        context 'when claim is invalid' do
          before do
            allow(claim).to receive(:valid?).with(:run_686_form_jobs).and_return(false)
          end

          it 'returns failed response with validation error' do
            result = job.send(:submit_claim_to_service, claim)

            expect(result.status).to be false
            expect(result.success?).to be false
            expect(result.error).to match(/Invalid686cClaim/)
          end

          it 'does not call submit_686c_form when invalid' do
            expect(job).not_to receive(:submit_686c_form)
            job.send(:submit_claim_to_service, claim)
          end

          it 'tracks the validation error' do
            expect(monitor).to receive(:track_submission_error).with(
              match(/Submission attempt failure/),
              'claim.error',
              error: an_instance_of(DependentsBenefits::Invalid686cClaim),
              parent_claim_id: parent_claim.id,
              saved_claim_id: claim.id
            )
            job.send(:submit_claim_to_service, claim)
          end

          it 'marks submission attempt as failed with validation error' do
            expect(job).to receive(:mark_submission_attempt_failed).with(
              submission_attempt,
              an_instance_of(DependentsBenefits::Invalid686cClaim)
            )
            job.send(:submit_claim_to_service, claim)
          end
        end
      end

      context 'when claim is SCHOOL_ATTENDANCE_APPROVAL (674) form' do
        let(:claim) { create(:student_claim) }

        before do
          allow(claim).to receive(:form_id).and_return(DependentsBenefits::SCHOOL_ATTENDANCE_APPROVAL)
          allow(job).to receive(:find_or_create_form_submission).with(claim).and_return(submission)
        end

        context 'when claim is valid' do
          before do
            allow(claim).to receive(:valid?).with(:run_686_form_jobs).and_return(true)
            allow(job).to receive(:submit_674_form).with(claim)
          end

          it 'processes the 674 form successfully' do
            expect(job).to receive(:submit_674_form).with(claim)
            expect(job).to receive(:mark_submission_attempt_succeeded).with(submission_attempt)

            result = job.send(:submit_claim_to_service, claim)

            expect(result.status).to be true
            expect(result.success?).to be true
          end

          it 'adds veteran info to claim before submission' do
            expect(claim).to receive(:add_veteran_info).with(user_data_hash)
            job.send(:submit_claim_to_service, claim)
          end

          it 'validates claim with run_686_form_jobs context' do
            expect(claim).to receive(:valid?).with(:run_686_form_jobs)
            job.send(:submit_claim_to_service, claim)
          end
        end

        context 'when claim is invalid' do
          before do
            allow(claim).to receive(:valid?).with(:run_686_form_jobs).and_return(false)
          end

          it 'returns failed response with validation error' do
            result = job.send(:submit_claim_to_service, claim)

            expect(result.status).to be false
            expect(result.success?).to be false
            expect(result.error).to match(/Invalid674Claim/)
          end

          it 'does not call submit_674_form when invalid' do
            expect(job).not_to receive(:submit_674_form)
            job.send(:submit_claim_to_service, claim)
          end

          it 'tracks the validation error' do
            expect(monitor).to receive(:track_submission_error).with(
              match(/Submission attempt failure/),
              'claim.error',
              error: an_instance_of(DependentsBenefits::Invalid674Claim),
              parent_claim_id: parent_claim.id,
              saved_claim_id: claim.id
            )
            job.send(:submit_claim_to_service, claim)
          end

          it 'marks submission attempt as failed with validation error' do
            expect(job).to receive(:mark_submission_attempt_failed).with(
              submission_attempt,
              an_instance_of(DependentsBenefits::Invalid674Claim)
            )
            job.send(:submit_claim_to_service, claim)
          end
        end
      end

      context 'when claim has unsupported form_id' do
        before do
          allow(claim).to receive(:form_id).and_return('UNSUPPORTED_FORM')
        end

        it 'skips form-specific submission but still marks attempt as succeeded' do
          expect(job).not_to receive(:submit_686c_form)
          expect(job).not_to receive(:submit_674_form)
          expect(job).to receive(:mark_submission_attempt_succeeded).with(submission_attempt)

          result = job.send(:submit_claim_to_service, claim)

          expect(result.status).to be true
          expect(result.success?).to be true
        end
      end

      context 'when an error occurs during processing' do
        let(:error) { StandardError.new('Service error') }

        before do
          allow(claim).to receive(:form_id).and_return(DependentsBenefits::ADD_REMOVE_DEPENDENT)
          allow(job).to receive(:submit_686c_form).with(claim).and_raise(error)
        end

        it 'returns failed response with error message' do
          result = job.send(:submit_claim_to_service, claim)

          expect(result.status).to be false
          expect(result.success?).to be false
          expect(result.error).to eq('Service error')
        end

        it 'tracks submission error' do
          expect(monitor).to receive(:track_submission_error).with(
            match(/Submission attempt failure/),
            'claim.error',
            error:,
            parent_claim_id: parent_claim.id,
            saved_claim_id: claim.id
          )

          job.send(:submit_claim_to_service, claim)
        end

        it 'marks submission attempt as failed' do
          expect(job).to receive(:mark_submission_attempt_failed).with(submission_attempt, error)
          job.send(:submit_claim_to_service, claim)
        end

        it 'does not mark submission attempt as succeeded when error occurs' do
          expect(job).not_to receive(:mark_submission_attempt_succeeded)
          job.send(:submit_claim_to_service, claim)
        end
      end

      context 'when error occurs before submission attempt creation' do
        let(:error) { StandardError.new('Database error') }

        before do
          allow(job).to receive(:create_form_submission_attempt).with(submission).and_raise(error)
        end

        it 'still handles the error and marks attempt as failed' do
          # submission_attempt will be nil when create_form_submission_attempt raises error
          expect(job).to receive(:mark_submission_attempt_failed).with(nil, error)

          result = job.send(:submit_claim_to_service, claim)

          expect(result.status).to be false
          expect(result.error).to eq('Database error')
        end
      end
    end
  end

  describe '#mark_parent_group_succeeded' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }

    before do
      allow(job).to receive(:parent_claim_id).and_return(parent_claim.id)
    end

    it 'marks the parent claim group as succeeded' do
      expect do
        job.send(:mark_parent_group_succeeded)
        parent_claim_group.reload
      end.to change(parent_claim_group, :status).to(SavedClaimGroup::STATUSES[:SUCCESS])
    end
  end

  describe '#mark_parent_group_failed' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }

    before do
      allow(job).to receive(:parent_claim_id).and_return(parent_claim.id)
    end

    it 'marks the parent claim group as failed' do
      expect do
        job.send(:mark_parent_group_failed)
        parent_claim_group.reload
      end.to change(parent_claim_group, :status).to(SavedClaimGroup::STATUSES[:FAILURE])
    end
  end

  describe '#saved_claim' do
    it 'retrieves the SavedClaim by claim_id' do
      allow(job).to receive(:claim_id).and_return(saved_claim.id)
      result = job.send(:saved_claim)
      expect(result.id).to eq(saved_claim.id)
    end
  end
end
