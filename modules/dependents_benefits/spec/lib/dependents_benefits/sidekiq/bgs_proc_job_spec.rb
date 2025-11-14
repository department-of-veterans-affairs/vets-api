# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::Sidekiq::BGSProcJob, type: :job do
  before do
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    # Set up job with parent claim ID and initialize required instance variables
    job.instance_variable_set(:@claim_id, parent_claim.id)

    # Mock service dependencies
    allow(job).to receive(:generate_user_struct).and_return(user)
    allow(BGSV2::Service).to receive(:new).and_return(bgs_service)
    allow(DependentsBenefits::ClaimProcessor).to receive(:new).and_return(claim_processor)
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:child_claim) { create(:add_remove_dependents_claim) }
  let(:user_data) { DependentsBenefits::UserData.new(user, parent_claim.parsed_form).get_user_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim: child_claim, parent_claim:) }
  let(:job) { described_class.new }
  let(:bgs_service) { instance_double(BGSV2::Service) }
  let(:proc_id) { '123456' }
  let(:claim_processor) { instance_double(DependentsBenefits::ClaimProcessor) }

  describe '#perform' do
    it 'calls super perform method' do
      expect(bgs_service).to receive(:create_proc).and_return({ vnp_proc_id: proc_id })
      expect(bgs_service).to receive(:create_proc_form).with(proc_id, '21-686c')
      expect(bgs_service).to receive(:create_proc_form).with(proc_id, '21-674')
      expect(DependentsBenefits::ClaimProcessor).to receive(:enqueue_submissions).with(parent_claim.id, proc_id)
      expect { job.perform(parent_claim.id) }.not_to raise_error
    end
  end

  describe '#submit_to_service' do
    before do
      job.instance_variable_set(:@claim_id, parent_claim.id)
    end

    context 'when submission succeeds' do
      before do
        allow(bgs_service).to receive(:create_proc).and_return({ vnp_proc_id: proc_id })
        allow(bgs_service).to receive(:create_proc_form)
      end

      it 'creates a proc with Started state and returns success response' do
        result = job.submit_to_service

        expect(bgs_service).to have_received(:create_proc).with(proc_state: 'Started')
        expect(result.status).to be true
        expect(result.data[:proc_id]).to eq(proc_id)
      end

      it 'creates proc forms for each child claim' do
        job.submit_to_service

        expect(bgs_service).to have_received(:create_proc_form).with(proc_id, '21-686c')
      end

      it 'sets the proc_id instance variable' do
        job.submit_to_service

        expect(job.instance_variable_get(:@proc_id)).to eq(proc_id)
      end
    end

    context 'when BGS service fails' do
      let(:error) { StandardError.new('BGS service unavailable') }

      before do
        allow(bgs_service).to receive(:create_proc).and_raise(error)
      end

      it 'returns failure response with error' do
        result = job.submit_to_service

        expect(result.status).to be false
        expect(result.error).to eq(error)
      end
    end

    context 'when create_proc_form fails' do
      let(:error) { StandardError.new('Form creation failed') }

      before do
        allow(bgs_service).to receive(:create_proc).and_return({ vnp_proc_id: proc_id })
        allow(bgs_service).to receive(:create_proc_form).and_raise(error)
      end

      it 'returns failure response with error' do
        result = job.submit_to_service

        expect(result.status).to be false
        expect(result.error).to eq(error)
      end
    end
  end

  describe 'private methods' do
    describe '#handle_job_success' do
      before do
        job.instance_variable_set(:@proc_id, proc_id)
        job.instance_variable_set(:@parent_claim_id, parent_claim.id)
        allow(job).to receive(:mark_submission_succeeded)
        allow(DependentsBenefits::ClaimProcessor).to receive(:enqueue_submissions)
        allow(job).to receive(:monitor).and_return(double('monitor', track_submission_error: nil))
      end

      context 'when success handling succeeds' do
        it 'marks submission as succeeded and enqueues submissions' do
          job.send(:handle_job_success)

          expect(job).to have_received(:mark_submission_succeeded)
          expect(DependentsBenefits::ClaimProcessor).to have_received(:enqueue_submissions)
            .with(parent_claim.id, proc_id)
        end
      end

      context 'when success handling fails' do
        let(:error) { StandardError.new('Success handling error') }
        let(:monitor) { double('monitor') }

        before do
          allow(job).to receive(:mark_submission_succeeded).and_raise(error)
          allow(job).to receive(:monitor).and_return(monitor)
        end

        it 'tracks the error with monitor' do
          expect(monitor).to receive(:track_submission_error).with(
            'Error handling job success',
            'success_failure',
            error:
          )

          job.send(:handle_job_success)
        end
      end
    end

    describe '#find_or_create_form_submission' do
      let(:submission) { instance_double(BGS::Submission) }

      before do
        allow(BGS::Submission).to receive(:find_or_create_by).and_return(submission)
      end

      it 'finds or creates BGS submission with form 686C-674' do
        result = job.send(:find_or_create_form_submission)

        expect(BGS::Submission).to have_received(:find_or_create_by).with(
          form_id: '686C-674',
          saved_claim_id: parent_claim.id
        )
        expect(result).to eq(submission)
      end

      it 'memoizes the submission' do
        job.send(:find_or_create_form_submission)
        job.send(:find_or_create_form_submission)

        expect(BGS::Submission).to have_received(:find_or_create_by).once
      end
    end

    describe '#create_form_submission_attempt' do
      let(:submission) { instance_double(BGS::Submission) }
      let(:submission_attempt) { instance_double(BGS::SubmissionAttempt) }

      before do
        allow(job).to receive(:submission).and_return(submission)
        allow(BGS::SubmissionAttempt).to receive(:create).and_return(submission_attempt)
      end

      it 'creates submission attempt linked to submission' do
        result = job.send(:create_form_submission_attempt)

        expect(BGS::SubmissionAttempt).to have_received(:create).with(submission:)
        expect(result).to eq(submission_attempt)
      end

      it 'memoizes the submission attempt' do
        job.send(:create_form_submission_attempt)
        job.send(:create_form_submission_attempt)

        expect(BGS::SubmissionAttempt).to have_received(:create).once
      end
    end

    describe '#mark_submission_succeeded' do
      let(:submission_attempt) { instance_double(BGS::SubmissionAttempt) }

      before do
        allow(job).to receive(:submission_attempt).and_return(submission_attempt)
        allow(submission_attempt).to receive(:success!)
      end

      it 'marks submission attempt as successful' do
        job.send(:mark_submission_succeeded)

        expect(submission_attempt).to have_received(:success!)
      end

      context 'when submission_attempt is nil' do
        before do
          allow(job).to receive(:submission_attempt).and_return(nil)
        end

        it 'does not raise error' do
          expect { job.send(:mark_submission_succeeded) }.not_to raise_error
        end
      end
    end

    describe '#mark_submission_attempt_failed' do
      let(:submission_attempt) { instance_double(BGS::SubmissionAttempt) }
      let(:exception) { StandardError.new('Test error') }

      before do
        allow(job).to receive(:submission_attempt).and_return(submission_attempt)
        allow(submission_attempt).to receive(:fail!)
      end

      it 'marks submission attempt as failed with error details' do
        job.send(:mark_submission_attempt_failed, exception)

        expect(submission_attempt).to have_received(:fail!).with(error: exception)
      end

      context 'when submission_attempt is nil' do
        before do
          allow(job).to receive(:submission_attempt).and_return(nil)
        end

        it 'does not raise error' do
          expect { job.send(:mark_submission_attempt_failed, exception) }.not_to raise_error
        end
      end
    end

    describe '#mark_submission_failed' do
      it 'is a no-op for BGS submissions' do
        expect(job.send(:mark_submission_failed, StandardError.new)).to be_nil
      end
    end

    describe 'memoization methods' do
      let(:submission) { instance_double(BGS::Submission) }
      let(:submission_attempt) { instance_double(BGS::SubmissionAttempt) }

      describe '#submission' do
        before do
          allow(job).to receive(:find_or_create_form_submission).and_return(submission)
        end

        it 'delegates to find_or_create_form_submission and memoizes' do
          result1 = job.send(:submission)
          result2 = job.send(:submission)

          expect(job).to have_received(:find_or_create_form_submission).once
          expect(result1).to eq(submission)
          expect(result2).to eq(submission)
        end
      end

      describe '#submission_attempt' do
        before do
          allow(job).to receive(:create_form_submission_attempt).and_return(submission_attempt)
        end

        it 'delegates to create_form_submission_attempt and memoizes' do
          result1 = job.send(:submission_attempt)
          result2 = job.send(:submission_attempt)

          expect(job).to have_received(:create_form_submission_attempt).once
          expect(result1).to eq(submission_attempt)
          expect(result2).to eq(submission_attempt)
        end
      end
    end
  end
end
