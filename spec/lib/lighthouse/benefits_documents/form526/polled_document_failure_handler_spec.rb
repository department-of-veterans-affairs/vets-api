# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/polled_document_failure_handler'

RSpec.describe BenefitsDocuments::Form526::PolledDocumentFailureHandler do
  subject { described_class }

  describe '#call' do
    context 'when the polled document was a piece of Veteran evidence' do
      let(:lighthouse526_document_upload) do
        create(
          :lighthouse526_document_upload,
          document_type: Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE
        )
      end

      it 'enqueues a EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail job' do
        form_attachment_guid = lighthouse526_document_upload.form_attachment.guid

        expect(EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail)
          .to receive(:perform_async).with(lighthouse526_document_upload.form526_submission_id, form_attachment_guid)

        subject.call(lighthouse526_document_upload)
      end
    end

    context 'when the polled document was a Form 0781' do
      let(:lighthouse526_document_upload) do
        create(
          :lighthouse526_document_upload,
          document_type: Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE
        )
      end

      it 'enqueues a EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail job' do
        expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail)
          .to receive(:perform_async).with(lighthouse526_document_upload.form526_submission_id)

        subject.call(lighthouse526_document_upload)
      end
    end

    context 'when the polled document was a Form 0781a' do
      let(:lighthouse526_document_upload) do
        create(
          :lighthouse526_document_upload,
          document_type: Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE
        )
      end

      it 'enqueues a EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail job' do
        expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail)
          .to receive(:perform_async).with(lighthouse526_document_upload.form526_submission_id)

        subject.call(lighthouse526_document_upload)
      end
    end
  end
end
