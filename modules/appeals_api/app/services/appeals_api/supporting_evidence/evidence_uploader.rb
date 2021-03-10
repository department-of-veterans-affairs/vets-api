# frozen_string_literal: true

module AppealsApi
  module SupportingEvidence
    class EvidenceUploader
      def initialize(appeal, document, type:)
        @appeal = appeal
        @document = document
        @type = type
        raise ArgumentError, 'invalid type' unless valid_type!
      end

      def process!
        generate_evidence_submission!
        uploader.store!(document)
        update_submission!
      end

      private

      attr_accessor :submission, :document, :appeal, :type

      def generate_evidence_submission!
        @submission = appeal.evidence_submissions.create!
      end

      def uploader
        @uploader ||= TemporaryStorageUploader.new(appeal.id, type)
      end

      def update_submission!
        @submission.update(
          status: 'submitted',
          file_data: {
            filename: uploader.filename
          }
        )
      end

      def valid_type!
        type.in?(%i[notice_of_disagreement])
      end
    end
  end
end
