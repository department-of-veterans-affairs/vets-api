# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/document_upload/lighthouse_supplemental_document_upload_provider'
require 'lighthouse/benefits_documents/form526/upload_supplemental_document_service'
require 'support/disability_compensation_form/shared_examples/supplemental_document_upload_provider'

RSpec.describe LighthouseSupplementalDocumentUploadProvider do
  let(:submission) { create(:form526_submission, :with_submitted_claim_id) }
  let(:submission_user) { User.find(submission.user_uuid) }
  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }
  let(:file_name) { Faker::File.file_name }

  # BDD Document Type
  let(:va_document_type) { 'L023' }

  let(:provider) do
    LighthouseSupplementalDocumentUploadProvider.new(
      submission,
      va_document_type,
      'my_stats_metric_prefix'
    )
  end

  let(:lighthouse_document) do
    LighthouseDocument.new(
      claim_id: submission.submitted_claim_id,
      participant_id: submission_user.participant_id,
      document_type: va_document_type,
      file_name:
    )
  end

  it_behaves_like 'supplemental document upload provider'

  describe 'generate_upload_document' do
    it 'generates a LighthouseDocument' do
      file_name = Faker::File.file_name

      upload_document = provider.generate_upload_document(file_name)

      expect(upload_document).to be_an_instance_of(LighthouseDocument)
      expect(upload_document).to have_attributes(
        {
          claim_id: submission.submitted_claim_id,
          participant_id: submission_user.participant_id,
          document_type: va_document_type,
          file_name:
        }
      )
    end
  end

  describe 'validate_upload_document' do
    context 'when the document is a valid LighthouseDocument' do
      it 'returns true' do
        allow_any_instance_of(LighthouseDocument).to receive(:valid?).and_return(true)
        expect(provider.validate_upload_document(lighthouse_document)).to eq(true)
      end
    end

    context 'when the document is an invalid LighthouseDocument' do
      it 'returns false' do
        allow_any_instance_of(LighthouseDocument).to receive(:valid?).and_return(false)
        expect(provider.validate_upload_document(lighthouse_document)).to eq(false)
      end
    end
  end

  describe 'submit_upload_document' do
    let(:faraday_response) { instance_double(Faraday::Response) }
    let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }

    before do
      allow(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
        .with(file_body, lighthouse_document)
        .and_return(faraday_response)

      allow(faraday_response).to receive(:body).and_return(
        {
          'data' => {
            'success' => true,
            'requestId' => lighthouse_request_id
          }
        }
      )
    end

    it 'uploads the document via the UploadSupplementalDocumentService' do
      expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
        .with(file_body, lighthouse_document)

      provider.submit_upload_document(lighthouse_document, file_body)
    end

    it 'increments a StatsD success metric' do
      expect(StatsD).to receive(:increment).with(
        'my_stats_metric_prefix.lighthouse_supplemental_document_upload_provider.success'
      )

      provider.submit_upload_document(lighthouse_document, file_body)
    end

    it 'creates a pending Lighthouse526DocumentUpload record for the submission so we can poll Lighthouse later' do
      upload_attributes = {
        aasm_state: 'pending',
        form526_submission_id: submission.id,
        # Polling record type mapped to L023 used in tests
        document_type: Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE,
        lighthouse_document_request_id: lighthouse_request_id
      }

      expect do
        provider.submit_upload_document(lighthouse_document, file_body)
      end.to change { Lighthouse526DocumentUpload.where(**upload_attributes).count }.by(1)
    end
  end

  describe 'logging methods' do
    # We don't want to generate an actual submission for these tests,
    # since submissions have callbacks that log to StatsD and we need to test
    # only the metrics in this class
    let(:submission) { instance_double(Form526Submission) }

    let(:provider) do
      LighthouseSupplementalDocumentUploadProvider.new(
        submission,
        'MyUploadingClass',
        'my_stats_metric_prefix'
      )
    end

    describe 'log_upload_failure' do
      let(:error_class) { 'StandardError' }
      let(:error_message) { 'Something broke' }

      it 'increments a StatsD failure metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.lighthouse_supplemental_document_upload_provider.failed'
        )
        provider.log_upload_failure(error_class, error_message)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          'LighthouseSupplementalDocumentUploadProvider upload failure',
          {
            class: 'LighthouseSupplementalDocumentUploadProvider',
            error_class:,
            error_message:
          }
        )

        provider.log_upload_failure(error_class, error_message)
      end
    end
  end
end
