# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/document_upload/evss_supplemental_document_upload_provider'
require 'support/disability_compensation_form/shared_examples/supplemental_document_upload_provider'

RSpec.describe EVSSSupplementalDocumentUploadProvider do
  let(:submission) { create(:form526_submission) }
  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }
  let(:file_name) { Faker::File.file_name }

  let(:provider) do
    EVSSSupplementalDocumentUploadProvider.new(
      submission,
      file_body
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
      document_type = 'L023'

      upload_document = provider.generate_upload_document(file_name, document_type)

      expect(upload_document).to be_an_instance_of(EVSSClaimDocument)
      expect(upload_document).to have_attributes(
        {
          evss_claim_id: submission.submitted_claim_id,
          file_name:,
          document_type:
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
      let(:faraday_response) { instance_double(Faraday::Response) }

      it 'submits the document via the EVSSDocumentService and returns the API response' do
        allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
          .with(file_body, evss_claim_document)
          .and_return(faraday_response)

        expect(provider.submit_upload_document(evss_claim_document)).to eq(faraday_response)
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
        file_body
      )
    end

    describe 'log_upload_success' do
      it 'increments a StatsD success metric' do
        expect(StatsD).to receive(:increment).with(
          'my_upload_job_prefix.evss_supplemental_document_upload_provider.success'
        )
        provider.log_upload_success('my_upload_job_prefix')
      end
    end

    describe 'log_upload_error_retry' do
      it 'increments a StatsD retry metric and re-raises the error' do
        expect(StatsD).to receive(:increment).with(
          'my_upload_job_prefix.evss_supplemental_document_upload_provider.retried'
        )
        provider.log_upload_error_retry('my_upload_job_prefix')
      end
    end

    describe 'log_upload_failure' do
      let(:error) { StandardError.new }

      it 'increments a StatsD failure metric' do
        expect(StatsD).to receive(:increment).with(
          'my_upload_job_prefix.evss_supplemental_document_upload_provider.failed'
        )
        provider.log_upload_failure('my_upload_job_prefix', error)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          'EVSSSupplementalDocumentUploadProvider upload failure',
          {
            class: 'EVSSSupplementalDocumentUploadProvider',
            error_class: error.class,
            error_message: error.message
          }
        )

        provider.log_upload_failure('my_upload_job_prefix', error)
      end
    end
  end
end
