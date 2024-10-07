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

  let!(:provider) do
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

  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }

  # Mock Lighthouse API response
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
    it 'uploads the document via the UploadSupplementalDocumentService' do
      expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
        .with(file_body, lighthouse_document)

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

  describe 'events logging' do
    context 'when attempting to upload a document' do
      before do
        allow(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
        allow(provider).to receive(:handle_lighthouse_response)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:info).with(
          'LighthouseSupplementalDocumentUploadProvider upload attempted',
          {
            class: 'LighthouseSupplementalDocumentUploadProvider',
            submission_id: submission.submitted_claim_id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526'
          }
        )

        provider.submit_upload_document(lighthouse_document, file_body)
      end

      it 'increments a StatsD attempt metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.lighthouse_supplemental_document_upload_provider.upload_attempt'
        )

        provider.submit_upload_document(lighthouse_document, file_body)
      end
    end

    context 'when an upload is successful' do
      before do
        # Skip upload attempt logging
        allow(provider).to receive(:log_upload_attempt)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:info).with(
          'LighthouseSupplementalDocumentUploadProvider upload successful',
          {
            class: 'LighthouseSupplementalDocumentUploadProvider',
            submission_id: submission.submitted_claim_id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526',
            lighthouse_request_id:
          }
        )

        provider.submit_upload_document(lighthouse_document, file_body)
      end

      it 'increments a StatsD success metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.lighthouse_supplemental_document_upload_provider.upload_success'
        )

        provider.submit_upload_document(lighthouse_document, file_body)
      end
    end

    context 'when we get a non-200 response from Lighthouse' do
      let(:error_response_body) do
        # From vcr_cassettes/lighthouse/benefits_claims/documents/lighthouse_form_526_document_upload_400.yml
        {
          'errors' => [
            {
              'detail' => 'Something broke',
              'status' => 400,
              'title' => 'Bad Request',
              'instance' => Faker::Internet.uuid
            }
          ]
        }
      end

      before do
        # Skip upload attempt logging
        allow(provider).to receive(:log_upload_attempt)

        allow(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
          .with(file_body, lighthouse_document)
          .and_return(faraday_response)

        allow(faraday_response).to receive(:body).and_return(error_response_body)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          'LighthouseSupplementalDocumentUploadProvider upload failed',
          {
            class: 'LighthouseSupplementalDocumentUploadProvider',
            submission_id: submission.submitted_claim_id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526',
            lighthouse_error_response: error_response_body
          }
        )

        provider.submit_upload_document(lighthouse_document, file_body)
      end

      it 'increments a StatsD metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.lighthouse_supplemental_document_upload_provider.upload_failure'
        )

        provider.submit_upload_document(lighthouse_document, file_body)
      end
    end

    context 'uploading job failure' do
      let(:uploading_job_class) { 'MyUploadJob' }
      let(:error_class) { 'StandardError' }
      let(:error_message) { 'Something broke' }

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          "#{uploading_job_class} LighthouseSupplementalDocumentUploadProvider Failure",
          {
            class: 'LighthouseSupplementalDocumentUploadProvider',
            submission_id: submission.submitted_claim_id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526',
            uploading_job_class:,
            error_class:,
            error_message:
          }
        )

        provider.log_uploading_job_failure(uploading_job_class, error_class, error_message)
      end

      it 'increments a StatsD failure metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.lighthouse_supplemental_document_upload_provider.upload_job_failed'
        )
        provider.log_uploading_job_failure(uploading_job_class, error_class, error_message)
      end
    end
  end
end
