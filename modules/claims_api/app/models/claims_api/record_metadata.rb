# frozen_string_literal: true

module ClaimsApi
  # General purpose model for storing metadata associated with various records.
  # For example, a SOAP request that resulted in an error when establishing a Power of Attorney request.
  class RecordMetadata < ApplicationRecord
    # rubocop:disable Rails/UnusedIgnoredColumns
    # Deprecating record_type and record_id as those columns are being removed:
    self.ignored_columns += ['record_type']
    self.ignored_columns += ['record_id']
    # rubocop:enable Rails/UnusedIgnoredColumns

    has_kms_key
    has_encrypted :metadata, key: :kms_key, **lockbox_options
    has_encrypted :request_url, key: :kms_key, **lockbox_options
    has_encrypted :request_headers, key: :kms_key, **lockbox_options
    has_encrypted :request, key: :kms_key, **lockbox_options
    has_encrypted :response, key: :kms_key, **lockbox_options
  end
end
