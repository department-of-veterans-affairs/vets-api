# frozen_string_literal: true

module DebtsApi
  module V0
    class Form5655SubmissionSerializer
      def initialize(submission)
        @submission = submission
      end

      def serialize
        {
          'id' => @submission.id,
          'created_at' => @submission.created_at,
          'updated_at' => @submission.updated_at,
          'state' => @submission.state,
          'metadata' => serialize_metadata
        }
      end

      private

      def serialize_metadata
        return {} if @submission.public_metadata.blank?

        {
          'debt_type' => @submission.public_metadata['debt_type'],
          'streamlined' => @submission.public_metadata['streamlined'],
          'combined' => @submission.public_metadata['combined'],
          'debt_identifiers' => @submission.debt_identifiers
        }
      end
    end
  end
end
