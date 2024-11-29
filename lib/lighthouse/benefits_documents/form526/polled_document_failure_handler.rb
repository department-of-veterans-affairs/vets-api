# frozen_string_literal: true

# Service for taking action when we poll Lighthouse for the status of
# a Lighthouse526DocumentUpload polling record. When Lighthouse marks the
# record as failed in their system, this class handles any
# post-polling actions to deal with the failure.
module BenefitsDocuments
  module Form526
    class PolledDocumentFailureHandler
      def self.call(*)
        new.call(*)
      end

      # @params lighthouse526_document_upload [Lighthouse526DocumentUpload] the polling record we
      # queried at Lighthouse that Lighthouse has marked failed
      def call(lighthouse526_document_upload)
        @lighthouse526_document_upload = lighthouse526_document_upload
        enqueue_veteran_failure_mailer
      end

      private

      # Enqueues a mailer to send to the Veteran to inform them a document has failed to
      # finish processing, and that they will need to take manual steps to address the situation.
      # The mailer we send is based on the type of document that failed.
      def enqueue_veteran_failure_mailer
        case @lighthouse526_document_upload.document_type
        when Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE
          enqueue_veteran_evidence_failure_mailer
        when Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE, Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE
          enqueue_0781_failure_mailer
        end
      end

      def enqueue_veteran_evidence_failure_mailer
        form526_submission_id = @lighthouse526_document_upload.form526_submission_id
        form_attachment_guid = @lighthouse526_document_upload.form_attachment.guid

        EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail
          .perform_async(form526_submission_id, form_attachment_guid)
      end

      def enqueue_0781_failure_mailer
        EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail
          .perform_async(@lighthouse526_document_upload.form526_submission_id)
      end
    end
  end
end
