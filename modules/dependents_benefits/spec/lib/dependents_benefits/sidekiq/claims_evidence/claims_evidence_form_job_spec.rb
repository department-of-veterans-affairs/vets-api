# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/uploader'
require 'dependents_benefits/user_data'

RSpec.describe DependentsBenefits::Sidekiq::ClaimsEvidence::ClaimsEvidenceFormJob, type: :job do
  before do
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  # Create a concrete test subclass to test the abstract base class
  let(:test_job_class) do
    Class.new(described_class) do
      def invalid_claim_error_class
        DependentsBenefits::Sidekiq::DependentSubmissionError
      end

      def form_id
        '21-674'
      end
    end
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:saved_claim) { create(:student_claim) }
  let(:user_data) { DependentsBenefits::UserData.new(user, saved_claim.parsed_form).get_user_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim:, parent_claim:) }
  let(:job) { test_job_class.new }
  let(:claims_evidence_uploader) { instance_double(ClaimsEvidenceApi::Uploader) }
  let(:lighthouse_submission) { instance_double(DependentsBenefits::BenefitsIntake::LighthouseSubmission) }

  describe '#form_id' do
    context 'when not implemented by subclass' do
      it 'raises NotImplementedError' do
        direct_job = described_class.new
        expect { direct_job.form_id }.to raise_error(NotImplementedError, 'Subclasses must implement form_id method')
      end
    end

    context 'when implemented by subclass' do
      it 'returns the form id' do
        expect(job.form_id).to eq('21-674')
      end
    end
  end

  describe '#submit_to_service' do
    before do
      allow(job).to receive_messages(saved_claim:, claims_evidence_uploader:,
                                     lighthouse_submission:)
      allow(claims_evidence_uploader).to receive(:upload_evidence).and_return(true)
      allow(lighthouse_submission).to receive(:process_pdf).and_return('file_path')
      allow(saved_claim).to receive(:to_pdf).with(form_id: '21-674').and_return('tmp/pdfs/mock_form_final.pdf')
    end

    it 'processes PDF and uploads evidence' do
      expect(lighthouse_submission).to receive(:process_pdf).with(
        'tmp/pdfs/mock_form_final.pdf',
        saved_claim.created_at,
        '21-674'
      )
      expect(claims_evidence_uploader).to receive(:upload_evidence).with(
        saved_claim.id,
        file_path: 'file_path',
        form_id: '21-674',
        doctype: saved_claim.document_type
      )

      result = job.submit_to_service
      expect(result).to be_a(DependentsBenefits::ServiceResponse)
      expect(result.status).to be true
    end

    it 'returns error response when exception occurs' do
      error = StandardError.new('Test error')
      allow(lighthouse_submission).to receive(:process_pdf).and_raise(error)

      result = job.submit_to_service
      expect(result).to be_a(DependentsBenefits::ServiceResponse)
      expect(result.status).to be false
      expect(result.error).to eq(error)
    end
  end

  describe '#find_or_create_form_submission' do
    before do
      allow(job).to receive(:saved_claim).and_return(saved_claim)
    end

    it 'creates a ClaimsEvidenceApi::Submission record' do
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(
        form_id: '21-674',
        saved_claim_id: saved_claim.id
      )
      job.find_or_create_form_submission
    end
  end

  describe '#create_form_submission_attempt' do
    let(:submission) { create(:claims_evidence_submission, saved_claim:, form_id: '21-674') }

    before do
      allow(job).to receive(:submission).and_return(submission)
    end

    it 'creates a ClaimsEvidenceApi::SubmissionAttempt record' do
      expect do
        job.send(:create_form_submission_attempt)
      end.to change(ClaimsEvidenceApi::SubmissionAttempt, :count).by(1)
    end
  end

  describe '#mark_submission_succeeded' do
    let(:submission) { create(:claims_evidence_submission, saved_claim:, form_id: '21-674') }
    let(:submission_attempt) { create(:claims_evidence_submission_attempt, submission:, status: 'pending') }

    before do
      allow(job).to receive(:submission_attempt).and_return(submission_attempt)
    end

    it 'marks attempt as accepted' do
      expect { job.send(:mark_submission_succeeded) }
        .to change { submission_attempt.reload.status }.from('pending').to('accepted')
    end
  end

  describe '#mark_submission_attempt_failed' do
    let(:submission) { create(:claims_evidence_submission, saved_claim:, form_id: '21-674') }
    let(:submission_attempt) { create(:claims_evidence_submission_attempt, submission:, status: 'pending') }
    let(:error) { StandardError.new('Test error') }

    before do
      allow(job).to receive(:submission_attempt).and_return(submission_attempt)
    end

    it 'marks attempt as failed with error' do
      expect(submission_attempt).to receive(:fail!).with(error:)
      job.mark_submission_attempt_failed(error)
    end
  end

  describe '#mark_submission_failed' do
    it 'is a no-op that returns nil' do
      error = StandardError.new('Test error')
      result = job.mark_submission_failed(error)
      expect(result).to be_nil
    end
  end

  describe '#permanent_failure?' do
    context 'with nil error' do
      it 'returns false' do
        expect(job.permanent_failure?(nil)).to be false
      end
    end

    context 'with non-VEFS error' do
      it 'returns false' do
        error = StandardError.new('Regular error')
        expect(job.permanent_failure?(error)).to be false
      end
    end

    context 'with VEFS error' do
      let(:vefs_error) { ClaimsEvidenceApi::Exceptions::VefsError.new(ClaimsEvidenceApi::Exceptions::VefsError::INVALID_JWT) }

      it 'returns true for permanent error codes' do
        expect(job.permanent_failure?(vefs_error)).to be true
      end

      it 'returns false for non-permanent error codes' do
        transient_error = ClaimsEvidenceApi::Exceptions::VefsError.new('TEMPORARY_FAILURE')
        expect(job.permanent_failure?(transient_error)).to be false
      end
    end

    context 'with nested VEFS error' do
      let(:vefs_error) { ClaimsEvidenceApi::Exceptions::VefsError.new(ClaimsEvidenceApi::Exceptions::VefsError::UNAUTHORIZED) }
      let(:wrapper_error) do
        error = StandardError.new
        error.set_backtrace([])
        allow(error).to receive(:cause).and_return(vefs_error)
        error
      end

      it 'returns true for permanent error codes in cause' do
        expect(job.permanent_failure?(wrapper_error)).to be true
      end
    end
  end

  describe 'private methods' do
    before do
      allow(job).to receive_messages(saved_claim:, user_data:)
    end

    describe '#claims_evidence_uploader' do
      it 'creates uploader with folder identifier' do
        expect(ClaimsEvidenceApi::Uploader).to receive(:new).with(saved_claim.folder_identifier)
        job.send(:claims_evidence_uploader)
      end

      it 'memoizes the uploader instance' do
        uploader1 = job.send(:claims_evidence_uploader)
        uploader2 = job.send(:claims_evidence_uploader)
        expect(uploader1).to be(uploader2)
      end
    end

    describe '#lighthouse_submission' do
      it 'creates lighthouse submission with claim and user data' do
        expect(DependentsBenefits::BenefitsIntake::LighthouseSubmission).to receive(:new).with(saved_claim, user_data)
        job.send(:lighthouse_submission)
      end

      it 'memoizes the submission instance' do
        submission1 = job.send(:lighthouse_submission)
        submission2 = job.send(:lighthouse_submission)
        expect(submission1).to be(submission2)
      end
    end
  end
end
