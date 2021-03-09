# frozen_string_literal: true

module AppealsApi
  module SupportingEvidence
    class EvidenceUploader
      def initialize(appeal, document, type:)
        @document = document
        @type = type
        raise ArgumentError, 'invalid type' unless valid_type!
      end

      def process!
        generate_evidence_submission!
        uploader.store!(document)
        store_metadata!
        update_submission_status!

        #vbms_connect_job
      end

      private

      attr_accessor :submission, :document

      def generate_evidence_submission!
        @submission = appeal.evidence_submissions.create!
      end

      def store_metadata!
        @submission.update(file_data: {
          filename: uploader.filename
        })
      end

      def uploader
        @uploader ||= TemporaryStorageUploader.new(appeal.id, @type)
      end

      def update_submission_status!
        @submission.update(status: 'submitted')
      end

      def valid_type!
        type.in?(%i[notice_of_disagreement])
      end
    end
  end
end
