# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/bgs/bgs_form_job'
require 'bgsv2/service'

RSpec.describe DependentsBenefits::Sidekiq::BGS::BGSFormJob, type: :job do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    # Initialize job with current claim context
    job.instance_variable_set(:@claim_id, parent_claim.id)
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:saved_claim) { create(:add_remove_dependents_claim) }
  let(:user_data) { { 'veteran_information' => { 'full_name' => { 'first' => 'John', 'last' => 'Doe' } } }.to_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim:, parent_claim:) }
  let(:job) { described_class.new }

  describe '#find_or_create_form_submission' do
    it 'creates a new BGS::Submission if one does not exist' do
      expect do
        job.send(:find_or_create_form_submission, saved_claim)
      end.to change(BGS::Submission, :count).by(1)
    end

    it 'returns existing BGS::Submission if one already exists' do
      existing_submission = create(:bgs_submission, saved_claim:, form_id: '21-686C')

      result = job.send(:find_or_create_form_submission, saved_claim)

      expect(result).to eq(existing_submission)
      expect(BGS::Submission.count).to eq(1)
    end
  end

  describe '#create_form_submission_attempt' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }

    it 'creates a new BGS::SubmissionAttempt' do
      expect do
        job.send(:create_form_submission_attempt, submission)
      end.to change(BGS::SubmissionAttempt, :count).by(1)
    end

    it 'associates the attempt with the submission' do
      attempt = job.send(:create_form_submission_attempt, submission)

      expect(attempt.submission).to eq(submission)
    end
  end

  describe '#submission_previously_succeeded?' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }

    context 'when submission has a non-failure attempt' do
      before do
        create(:bgs_submission_attempt, submission:, status: 'submitted')
      end

      it 'returns true' do
        expect(job.send(:submission_previously_succeeded?, submission)).to be true
      end
    end

    context 'when submission has only failure attempts' do
      before do
        create(:bgs_submission_attempt, submission:, status: 'failure')
      end

      it 'returns false' do
        expect(job.send(:submission_previously_succeeded?, submission)).to be false
      end
    end

    context 'when submission is nil' do
      it 'returns false' do
        expect(job.send(:submission_previously_succeeded?, nil)).to be false
      end
    end
  end

  describe '#mark_submission_attempt_succeeded' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }

    it 'marks the submission attempt as submitted' do
      expect { job.send(:mark_submission_attempt_succeeded, submission_attempt) }
        .to change { submission_attempt.reload.status }.from('pending').to('submitted')
    end

    it 'handles nil submission_attempt gracefully' do
      expect { job.send(:mark_submission_attempt_succeeded, nil) }.not_to raise_error
    end
  end

  describe '#mark_submission_attempt_failed' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }
    let(:error) { StandardError.new('Test error') }

    it 'marks the submission attempt as failure' do
      expect { job.send(:mark_submission_attempt_failed, submission_attempt, error) }
        .to change { submission_attempt.reload.status }.from('pending').to('failure')
    end

    it 'records the error message' do
      job.send(:mark_submission_attempt_failed, submission_attempt, error)
      submission_attempt.reload

      expect(submission_attempt.error_message).to eq('Test error')
    end

    it 'handles nil submission_attempt gracefully' do
      expect { job.send(:mark_submission_attempt_failed, nil, error) }.not_to raise_error
    end
  end

  describe '#permanent_failure?' do
    before do
      stub_const('BGS::Job::FILTERED_ERRORS', %w[INVALID_SSN DUPLICATE_CLAIM])
    end

    context 'when error is nil' do
      it 'returns false' do
        expect(job.send(:permanent_failure?, nil)).to be false
      end
    end

    context 'when error message contains filtered error' do
      it 'returns true for INVALID_SSN' do
        error = StandardError.new('INVALID_SSN: Social Security Number is invalid')

        expect(job.send(:permanent_failure?, error)).to be true
      end

      it 'returns true for DUPLICATE_CLAIM' do
        error = StandardError.new('DUPLICATE_CLAIM: This claim already exists')

        expect(job.send(:permanent_failure?, error)).to be true
      end
    end

    context 'when error cause contains filtered error' do
      it 'returns true when cause message matches' do
        cause = StandardError.new('INVALID_SSN: Social Security Number is invalid')
        error = StandardError.new('Wrapped error')
        allow(error).to receive(:cause).and_return(cause)

        expect(job.send(:permanent_failure?, error)).to be true
      end
    end

    context 'when error does not contain filtered error' do
      it 'returns false' do
        error = StandardError.new('Temporary network error')

        expect(job.send(:permanent_failure?, error)).to be false
      end
    end
  end

  describe '#generate_proc_id' do
    let(:bgs_service) { instance_double(BGSV2::Service) }
    let(:monitor) { instance_double(DependentsBenefits::Monitor) }

    before do
      allow(BGSV2::Service).to receive(:new).and_return(bgs_service)
      allow(job).to receive_messages(monitor:, generate_user_struct: {}, saved_claim:)
    end

    context 'when proc ID generation succeeds' do
      before do
        allow(bgs_service).to receive_messages(create_proc: { vnp_proc_id: 'test-proc-id-123' }, create_proc_form: true)
        allow(saved_claim).to receive_messages(submittable_686?: true, submittable_674?: false)
      end

      it 'returns the generated proc ID' do
        proc_id = job.send(:generate_proc_id)

        expect(proc_id).to eq('test-proc-id-123')
      end

      it 'creates proc forms based on claim type' do
        expect(bgs_service).to receive(:create_proc_form).with('test-proc-id-123', '21-686c')

        job.send(:generate_proc_id)
      end
    end

    context 'when proc ID generation fails' do
      let(:error) { StandardError.new('BGS service unavailable') }

      before do
        allow(bgs_service).to receive(:create_proc).and_raise(error)
        allow(monitor).to receive(:track_submission_error)
      end

      it 'tracks the error with monitor' do
        expect(monitor).to receive(:track_submission_error).with(
          'Error generating proc ID',
          'proc_id_failure',
          hash_including(error:, parent_claim_id: parent_claim.id)
        )

        expect do
          job.send(:generate_proc_id)
        end.to raise_error(DependentsBenefits::Sidekiq::DependentSubmissionError)
      end

      it 'raises DependentSubmissionError' do
        expect do
          job.send(:generate_proc_id)
        end.to raise_error(DependentsBenefits::Sidekiq::DependentSubmissionError)
      end

      it 'wraps the original error' do
        job.send(:generate_proc_id)
      rescue DependentsBenefits::Sidekiq::DependentSubmissionError => e
        expect(e.message).to eq('BGS service unavailable')
      end
    end
  end
end
