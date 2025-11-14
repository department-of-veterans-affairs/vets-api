# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/uploader'
require 'dependents_benefits/user_data'

RSpec.describe DependentsBenefits::Sidekiq::Claims686cJob, type: :job do
  before do
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:saved_claim) { create(:add_remove_dependents_claim) }
  let(:user_data) { DependentsBenefits::UserData.new(user, saved_claim.parsed_form).get_user_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim:, parent_claim:) }
  let(:job) { described_class.new }
  let(:claims_evidence_uploader) { instance_double(ClaimsEvidenceApi::Uploader) }
  let(:lighthouse_submission) { instance_double(DependentsBenefits::BenefitsIntake::LighthouseSubmission) }
  let(:proc_id) { '123456' }

  describe '#perform' do
    before do
      allow(ClaimsEvidenceApi::Uploader).to receive(:new).and_return(claims_evidence_uploader)
      allow(DependentsBenefits::BenefitsIntake::LighthouseSubmission).to receive(:new).and_return(lighthouse_submission)
      allow(claims_evidence_uploader).to receive(:upload_evidence).and_return(true)
      allow(lighthouse_submission).to receive(:process_pdf).and_return('file_path')
    end

    context 'with valid claim' do
      it 'processes the claim successfully' do
        expect { job.perform(saved_claim.id, proc_id) }.not_to raise_error
      end

      it 'calls lighthouse and claims evidence service' do
        # Ensure the to_pdf mock is called on the specific instance used in the job
        allow_any_instance_of(DependentsBenefits::AddRemoveDependent).to receive(:to_pdf)
          .with(form_id: DependentsBenefits::ADD_REMOVE_DEPENDENT)
          .and_return('tmp/pdfs/mock_form_final.pdf')

        expect(lighthouse_submission).to receive(:process_pdf).with(
          'tmp/pdfs/mock_form_final.pdf',
          saved_claim.created_at,
          DependentsBenefits::ADD_REMOVE_DEPENDENT
        )
        expect(claims_evidence_uploader).to receive(:upload_evidence).with(
          saved_claim.id,
          file_path: 'file_path',
          form_id: DependentsBenefits::ADD_REMOVE_DEPENDENT,
          doctype: saved_claim.document_type
        )
        job.perform(saved_claim.id, proc_id)
      end
    end

    context 'with missing claim' do
      it 'raises error for non-existent claim' do
        expect { job.perform(999_999, proc_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with invalid claim' do
      it 'raises error for invalid claim' do
        allow_any_instance_of(DependentsBenefits::AddRemoveDependent)
          .to receive(:valid?)
          .with(:run_686_form_jobs)
          .and_return(false)
        expect { job.perform(saved_claim.id, proc_id) }
          .to raise_error(DependentsBenefits::Sidekiq::DependentSubmissionError)
      end
    end

    context 'with claims evidence service error' do
      it 'triggers backup job when permanent claims evidence failure occurs' do
        permanent_error = ClaimsEvidenceApi::Exceptions::VefsError.new('error')

        # Mock the submission to return a failed ServiceResponse
        failed_response = DependentsBenefits::ServiceResponse.new(status: false, error: permanent_error)
        allow(job).to receive(:submit_to_service).and_return(failed_response)

        # Mock permanent_failure? to return true for the original error
        allow(job).to receive(:permanent_failure?).with(instance_of(DependentsBenefits::Sidekiq::DependentSubmissionError)).and_return(true)

        expect(DependentsBenefits::Sidekiq::DependentBackupJob).to receive(:perform_async).with(parent_claim.id,
                                                                                                proc_id)

        expect { job.perform(saved_claim.id, proc_id) }.to raise_error(Sidekiq::JobRetry::Skip)
      end
    end
  end
end
