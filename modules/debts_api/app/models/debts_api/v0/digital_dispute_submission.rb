# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputeSubmission < ApplicationRecord
      STATS_KEY = 'api.digital_dispute_submission'
      self.table_name = 'digital_dispute_submissions'
      belongs_to :user_account, dependent: nil, optional: false
      has_kms_key
      has_encrypted :form_data, :metadata, key: :kms_key
      validates :user_uuid, presence: true
      enum :state, { pending: 0, submitted: 1, failed: 2 }

      def public_metadata
        super || {}
      end

      def parsed_metadata
        return {} if metadata.blank?

        @parsed_metadata ||= JSON.parse(metadata)
      rescue JSON::ParserError
        {}
      end

      def kms_encryption_context
        {
          model_name: 'DigitalDisputeSubmission',
          model_id: id
        }
      end

      def store_public_metadata
        return unless metadata

        disputes = parsed_metadata['disputes'] || parsed_metadata[:disputes] || []

        self.public_metadata = {
          'debt_types' => extract_debt_types(disputes),
          'dispute_reasons' => extract_dispute_reasons(disputes)
        }
      end

      def store_debt_identifiers(disputes)
        return unless disputes

        self.debt_identifiers = disputes.map { |d| d['composite_debt_id'] || d[:composite_debt_id] }.compact
      end

      def register_failure(message)
        failed!
        update(error_message: message)
      end

      def register_success
        submitted!
      end

      private

      def extract_debt_types(disputes)
        disputes.map { |d| d['debt_type'] || d[:debt_type] }.compact.uniq
      end

      def extract_dispute_reasons(disputes)
        disputes.map { |d| d['dispute_reason'] || d[:dispute_reason] }.compact.uniq
      end
    end
  end
end
