# frozen_string_literal: true

module AppealsApi
  module SupportingEvidence
    class EvidenceUploader
      include SentryLogging

      VALID_EVIDENCE_TYPES = %i[notice_of_disagreement].freeze

      def initialize(appeal, document, type:)
        @appeal = appeal
        @document = document
        @type = type
        raise ArgumentError, 'invalid type' unless valid_type?
      end

      def process!
        generate_evidence_submission!
        uploader.store!(document)
        update_submission!('submitted')
      rescue => e
        log_message_to_sentry('Error saving to S3', :warning, error: e.to_s)
        update_submission!('Error uploading')
        raise
      end

      private

      attr_accessor :submission, :document, :appeal, :type

      def generate_evidence_submission!
        @submission = appeal.evidence_submissions.create!
      end

      def uploader
        @uploader ||= TemporaryStorageUploader.new(appeal.id, type)
      end

      def update_submission!(status)
        @submission.update!(
          status: status,
          file_data: {
            filename: uploader.filename
          }
        )
      end

      def valid_type?
        type.in?(VALID_EVIDENCE_TYPES)
      end
    end
  end
end
