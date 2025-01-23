# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/document_upload/evss_supplemental_document_upload_provider'
require 'support/disability_compensation_form/shared_examples/supplemental_document_upload_provider'

RSpec.describe EVSSSupplementalDocumentUploadProvider do
  let(:submission) { create(:form526_submission, :with_submitted_claim_id) }
  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }
  let(:file_name) { Faker::File.file_name }

  let(:va_document_type) { 'L023' }

  let!(:provider) do
    EVSSSupplementalDocumentUploadProvider.new(
      submission,
      va_document_type,
      'my_stats_metric_prefix'
    )
  end

  let(:evss_claim_document) do
    EVSSClaimDocument.new(
      evss_claim_id: submission.submitted_claim_id,
      document_type: 'L023',
      file_name:
    )
  end

  before do
    # Disallow actual API calls
    allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
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
        expect(provider.validate_upload_document(evss_claim_document)).to be(true)
      end
    end

    context 'when the document is an invalid EVSSClaimDocument' do
      it 'returns false' do
        allow_any_instance_of(EVSSClaimDocument).to receive(:valid?).and_return(false)
        expect(provider.validate_upload_document(evss_claim_document)).to be(false)
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
    end
  end

  describe 'events logging' do
    context 'when attempting to upload a document' do
      before do
        # Skip success logging
        allow(provider).to receive(:log_upload_success)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:info).with(
          'EVSSSupplementalDocumentUploadProvider upload attempted',
          {
            class: 'EVSSSupplementalDocumentUploadProvider',
            submitted_claim_id: submission.submitted_claim_id,
            submission_id: submission.id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526'
          }
        )

        provider.submit_upload_document(evss_claim_document, file_body)
      end

      it 'increments a StatsD attempt metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.evss_supplemental_document_upload_provider.upload_attempt'
        )

        provider.submit_upload_document(evss_claim_document, file_body)
      end
    end

    context 'when an upload is successfull' do
      before do
        # Skip upload attempt logging
        allow(provider).to receive(:log_upload_attempt)
      end

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:info).with(
          'EVSSSupplementalDocumentUploadProvider upload successful',
          {
            class: 'EVSSSupplementalDocumentUploadProvider',
            submitted_claim_id: submission.submitted_claim_id,
            submission_id: submission.id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526'
          }
        )

        provider.submit_upload_document(evss_claim_document, file_body)
      end

      it 'increments a StatsD success metric' do
        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.evss_supplemental_document_upload_provider.upload_success'
        )

        provider.submit_upload_document(evss_claim_document, file_body)
      end
    end

    # The EVSS::DocumentsService client we used in this API provider has custom exception logic
    # for unsucessful upload responses from EVSS (which still have a 200 response code)
    # We want to preserve this behavior while logging the event for tracking purposes
    context 'when an upload raises an EVSS response error' do
      before do
        # Skip upload attempt logging
        allow(provider).to receive(:log_upload_attempt)
        allow_any_instance_of(EVSS::DocumentsService).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSError)
      end

      it 'logs to the Rails logger, increments a StatsD failure metric, and re-raises the error' do
        expect(Rails.logger).to receive(:error).with(
          'EVSSSupplementalDocumentUploadProvider upload failed',
          {
            class: 'EVSSSupplementalDocumentUploadProvider',
            submitted_claim_id: submission.submitted_claim_id,
            submission_id: submission.id,
            user_uuid: submission.user_uuid,
            va_document_type_code: va_document_type,
            primary_form: 'Form526'
          }
        )

        # Ensure we don't increment the success metric
        expect(StatsD).not_to receive(:increment).with(
          'my_stats_metric_prefix.evss_supplemental_document_upload_provider.upload_success'
        )

        expect(StatsD).to receive(:increment).with(
          'my_stats_metric_prefix.evss_supplemental_document_upload_provider.upload_failure'
        )

        expect { provider.submit_upload_document(evss_claim_document, file_body) }.to raise_exception(
          EVSS::ErrorMiddleware::EVSSError
        )
      end
    end

    # Will be called in the sidekiq_retries_exhausted block of the including job
    context 'uploading job failure' do
      let(:uploading_job_class) { 'MyUploadJob' }
      let(:error_class) { 'StandardError' }
      let(:error_message) { 'Something broke' }

      it 'logs to the Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          "#{uploading_job_class} EVSSSupplementalDocumentUploadProvider Failure",
          {
            class: 'EVSSSupplementalDocumentUploadProvider',
            submitted_claim_id: submission.submitted_claim_id,
            submission_id: submission.id,
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
          'my_stats_metric_prefix.evss_supplemental_document_upload_provider.upload_job_failed'
        )
        provider.log_uploading_job_failure(uploading_job_class, error_class, error_message)
      end
    end
  end
end
