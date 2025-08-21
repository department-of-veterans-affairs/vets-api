# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputeSubmission < ApplicationRecord
      STATS_KEY = 'api.digital_dispute_submission'
      self.table_name = 'digital_dispute_submissions'
      belongs_to :user_account, dependent: nil, optional: false
      has_many_attached :files
      has_kms_key
      has_encrypted :form_data, :metadata, key: :kms_key
      validates :user_uuid, presence: true
      validate :files_present
      validate :files_are_pdfs
      validate :files_size_within_limit
      enum :state, { pending: 0, submitted: 1, failed: 2 }

      MAX_FILE_SIZE = 1.megabyte
      ACCEPTED_CONTENT_TYPE = 'application/pdf'

      def parsed_metadata
        return {} if metadata.blank?

        @parsed_metadata ||= JSON.parse(metadata, symbolize_names: true)
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

        disputes = parsed_metadata[:disputes] || []

        self.public_metadata = {
          'debt_types' => extract_debt_types(disputes),
          'dispute_reasons' => extract_dispute_reasons(disputes)
        }
      end

      def store_debt_identifiers(disputes)
        return unless disputes

        self.debt_identifiers = disputes.map { |d| d[:composite_debt_id] }.compact
      end

      def register_failure(message)
        failed!
        update(error_message: message)
      end

      def register_success
        submitted!
      end

      private

      def files_present
        errors.add(:files, 'at least one file is required') unless files.attached?
      end

      def files_are_pdfs
        return unless files.attached?

        files.each_with_index do |file, index|
          errors.add(:files, "File #{index + 1} must be a PDF") unless file.content_type == ACCEPTED_CONTENT_TYPE
        end
      end

      def files_size_within_limit
        return unless files.attached?

        files.each_with_index do |file, index|
          errors.add(:files, "File #{index + 1} is too large (maximum is 1MB)") if file.byte_size > MAX_FILE_SIZE
        end
      end

      def extract_debt_types(disputes)
        disputes.map { |d| d[:debt_type] }.compact.uniq
      end

      def extract_dispute_reasons(disputes)
        disputes.map { |d| d[:dispute_reason] }.compact.uniq
      end
    end
  end
end
# rubocop:enable Rails/Pluck
