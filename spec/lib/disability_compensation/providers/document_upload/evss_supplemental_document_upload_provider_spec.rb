# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/document_upload/evss_supplemental_document_upload_provider'
require 'support/disability_compensation_form/shared_examples/supplemental_document_upload_provider'

RSpec.describe EVSSSupplementalDocumentUploadProvider do
  let(:submission) { create(:form526_submission) }
  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }
  let(:file_name) { Faker::File.file_name }

  let(:va_document_type) { 'L023' }

  let(:provider) do
    EVSSSupplementalDocumentUploadProvider.new(
      submission,
      va_document_type,
      'my_upload_job_prefix'
    )
  end

  let(:evss_claim_document) do
    EVSSClaimDocument.new(
      evss_claim_id: submission.submitted_claim_id,
      document_type: 'L023',
      file_name:
    )
  end

  it_behaves_like 'supplemental document upload provider'

  describe '#generate_upload_document' do
    it 'generates an EVSSClaimDocument' do
      file_name = Faker::File.file_name
      upload_document = provider.generate_upload_document(file_name)

      expect(upload_document).to be_an_instance_of(EVSSClaimDocument)
      expect(upload_document).to have_attributes(
        {
          evss_claim_id: submission.submitted_claim_id,
          file_name:,
          document_type: va_document_type
        }
      )
    end
  end

  describe '#validate_upload_document' do
    context 'when the document is a valid EVSSClaimDocument' do
      it 'returns true' do
        expect(provider.validate_upload_document(evss_claim_document)).to eq(true)
      end
    end

    context 'when the document is an invalid EVSSClaimDocument' do
      it 'returns false' do
        allow_any_instance_of(EVSSClaimDocument).to receive(:valid?).and_return(false)
        expect(provider.validate_upload_document(evss_claim_document)).to eq(false)
      end
    end
  end

  describe '#submit_upload_document' do
    context 'for a valid payload' do
      it 'submits the document via the EVSSDocumentService' do
        expect_any_instance_of(EVSS::DocumentsService).to receive(:upload)
          .with(file_body, evss_claim_document)

        provider.submit_upload_document(evss_claim_document, file_body)
      end

      it 'increments a StatsD success metric' do
        faraday_response = instance_double(Faraday::Response)

        allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
          .with(file_body, evss_claim_document)
          .and_return(faraday_response)

        expect(StatsD).to receive(:increment).with(
          'my_upload_job_prefix.evss_supplemental_document_upload_provider.success'
        )

        provider.submit_upload_document(evss_claim_document, file_body)
      end
    end
  end

  describe 'logging methods' do
    # We don't want to generate an actual submission for these tests,
    # since submissions have callbacks that log to StatsD and we need to test
    # only the metrics in this class
    let(:submission) { instance_double(Form526Submission) }
    let(:provider) do
      EVSSSupplementalDocumentUploadProvider.new(
        submission,
        va_document_type,
        'my_upload_job_prefix'
      )
    end

    describe 'log_upload_failure' do
      let(:error_class) { 'StandardError' }
      let(:error_message) { 'Something broke' }

      it 'increments a StatsD failure metric' do
        expect(StatsD).to receive(:increment).with(
          'my_upload_job_prefix.evss_supplemental_document_upload_provider.failed'
        )
        provider.log_upload_failure(error_class, error_message)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          'EVSSSupplementalDocumentUploadProvider upload failure',
          {
            class: 'EVSSSupplementalDocumentUploadProvider',
            error_class:,
            error_message:
          }
        )

        provider.log_upload_failure(error_class, error_message)
      end
    end
  end
end
