# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/monitor'
require 'dependents_benefits/sidekiq/dependent_submission_job'
require 'sidekiq/job_retry'

RSpec.describe DependentsBenefits::DependentSubmissionJob, type: :job do
  let(:job) { described_class.new }
  let(:parent_claim) { create(:dependents_claim) }
  let(:child_claim) { create(:add_remove_dependents_claim) }
  let(:sibling_claim) { create(:student_claim) }
  let(:claim_id) { child_claim.id }
  let(:failed_response) { double('ServiceResponse', success?: false, error: 'Service unavailable') }
  let(:successful_response) { double('ServiceResponse', success?: true) }
  let(:monitor) { instance_double(DependentsBenefits::Monitor) }

  before do
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)

    allow(DependentsBenefits::Monitor).to receive(:new).and_return(monitor)
    allow(job).to receive(:create_form_submission_attempt)
  end

  describe '#perform' do
    describe('#perform') do
      let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
      let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }

      it 'skips processing if the parent group failed' do
        parent_claim_group.update!(status: SavedClaimGroup::FAILURE)

        expect(job).not_to receive(:submit_to_service)
        job.perform(claim_id)
      end

      it 'handles successful submissions' do
        allow(job).to receive(:submit_to_service).and_return(successful_response)
        expect(job).to receive(:handle_job_success)

        job.perform(claim_id)
      end

      it 'handles failed submissions' do
        allow(job).to receive(:submit_to_service).and_return(failed_response)
        expect(job).to receive(:handle_job_failure).with(failed_response.error)

        job.perform(claim_id)
      end

      it 'handles errors' do
        allow(job).to receive(:submit_to_service).and_raise(StandardError, 'Unexpected error')
        expect(job).to receive(:handle_job_failure).with(instance_of(StandardError))

        job.perform(claim_id)
      end
    end
  end

  describe '#handle_job_success' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
    let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }
    let!(:sibling_claim_group) { create(:saved_claim_group, saved_claim: sibling_claim, parent_claim:) }

    before do
      allow(job).to receive(:claim_id).and_return(claim_id)
    end

    it 'marks the submission attempt and submission as succeeded' do
      allow(job).to receive(:all_siblings_succeeded?).and_return(false)
      expect(job).to receive(:mark_submission_succeeded)

      job.send(:handle_job_success)
    end

    context 'when siblings are pending' do
      it 'does not mark claim group as succeeded' do
        allow(job).to receive(:all_siblings_succeeded?).and_return(false)
        allow(job).to receive(:mark_submission_succeeded)
        expect(job).not_to receive(:mark_claim_group_succeeded)

        job.send(:handle_job_success)
      end
    end

    context 'when all siblings are successful' do
      before do
        allow(job).to receive(:all_siblings_succeeded?).and_return(true)
        allow(job).to receive(:mark_submission_succeeded)
      end

      it 'marks the claim group as succeeded' do
        expect(job).to receive(:mark_claim_group_succeeded)

        job.send(:handle_job_success)
      end

      context 'when any group is still pending' do
        it 'does not mark the parent claim group as succeeded' do
          expect(job).not_to receive(:mark_parent_claim_group_succeeded)
          expect(job).not_to receive(:send_success_notification)

          job.send(:handle_job_success)
        end
      end

      context 'when all claim jobs have succeeded' do
        it 'marks the parent claim group as succeeded and notifies user' do
          sibling_claim_group.update!(status: SavedClaimGroup::SUCCESS)
          expect(job).to receive(:mark_parent_claim_group_succeeded).and_call_original
          expect(job).to receive(:send_success_notification)

          job.send(:handle_job_success)
        end
      end
    end

    context 'when the parent has failed' do
      it 'does not mark the claim group or parent claim group as succeeded' do
        parent_claim_group.update!(status: SavedClaimGroup::FAILURE)
        allow(job).to receive(:mark_submission_succeeded)
        expect(job).not_to receive(:mark_parent_claim_group_succeeded)
        expect(job).not_to receive(:send_success_notification)

        job.send(:handle_job_success)
      end
    end
  end

  describe '#handle_job_failure' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
    let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }
    let!(:sibling_claim_group) { create(:saved_claim_group, saved_claim: sibling_claim, parent_claim:) }

    before do
      allow(job).to receive(:claim_id).and_return(claim_id)
      allow(monitor).to receive(:track_submission_error)
    end

    context 'when the failure is permanent' do
      before do
        allow(job).to receive(:permanent_failure?).and_return(true)
        allow(job).to receive(:mark_submission_attempt_failed)
      end

      it 'calls #handle_permanent_failure' do
        expect(job).to receive(:mark_submission_attempt_failed)
        expect(job).to receive(:handle_permanent_failure)
        expect { job.send(:handle_job_failure, 'Service destroyed') }.to raise_error(Sidekiq::JobRetry::Skip)
      end
    end

    context 'when the failure is transient' do
      before do
        allow(job).to receive(:permanent_failure?).and_return(false)
        allow(job).to receive(:mark_submission_attempt_failed)
      end

      it 'raises the error' do
        expect(job).to receive(:mark_submission_attempt_failed)
        expect { job.send(:handle_job_failure, 'Service destroyed') }.to raise_error('Service destroyed')
      end
    end
  end

  describe '#handle_permanent_failure' do
    let!(:parent_claim_group) { create(:parent_claim_group, parent_claim:) }
    let!(:child_claim_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }
    let!(:sibling_claim_group) { create(:saved_claim_group, saved_claim: sibling_claim, parent_claim:) }

    before do
      allow(job).to receive(:claim_id).and_return(claim_id)
      allow(monitor).to receive(:track_submission_error)
    end

    it 'marks the submission and claim group as failed' do
      expect(job).to receive(:mark_submission_failed)
      expect(job).to receive(:mark_claim_group_failed)

      job.send(:handle_permanent_failure, claim_id, 'Service destroyed')
    end

    context 'when the parent claim is already failed' do
      before do
        allow(job).to receive(:mark_submission_failed)
        parent_claim_group.update!(status: SavedClaimGroup::FAILURE)
      end

      it 'does not notify the user' do
        expect(job).not_to receive(:mark_parent_claim_group_failed)
        expect(job).not_to receive(:send_failure_notification)
        expect(monitor).not_to receive(:log_silent_failure_avoided)

        job.send(:handle_permanent_failure, claim_id, 'Service destroyed')
      end
    end

    context 'when the parent claim is pending' do
      before do
        allow(job).to receive(:mark_submission_failed)
      end

      it 'sends the backup job' do
        expect(job).to receive(:send_backup_job)

        job.send(:handle_permanent_failure, claim_id, 'Service destroyed')
      end
    end

    context 'when there is an error in the process' do
      it 'notifies the user' do
        allow(job).to receive(:mark_submission_failed)
        allow(job).to receive(:send_backup_job).and_raise(StandardError, 'Submission not found')
        expect(monitor).to receive(:log_silent_failure_avoided)

        job.send(:handle_permanent_failure, claim_id, 'Service destroyed')
      end

      it 'logs a silent failure if notification fails' do
        allow(job).to receive(:mark_submission_failed).and_raise(StandardError, 'Submission not found')
        allow(job).to receive(:send_failure_notification).and_raise(StandardError, 'User not found')
        expect(monitor).to receive(:log_silent_failure)

        job.send(:handle_permanent_failure, claim_id, 'Service destroyed')
      end
    end
  end

  describe '#sidekiq_retries_exhausted' do
    it 'logs a distinct error when no claim_id provided' do
      described_class.within_sidekiq_retries_exhausted_block({ 'args' => [claim_id, 'proc_id'] }, 'Failure!') do
        allow(described_class).to receive(:new).and_return(job)
        expect(job).to receive(:handle_permanent_failure).with(claim_id, 'Failure!')
      end
    end
  end
end
