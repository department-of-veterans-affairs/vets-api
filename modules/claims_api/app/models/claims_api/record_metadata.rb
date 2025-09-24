# frozen_string_literal: true

module ClaimsApi
  # General purpose model for storing metadata associated with various records.
  # For example, a SOAP request that resulted in an error when establishing a Power of Attorney request.
  class RecordMetadata < ApplicationRecord
    has_kms_key
    has_encrypted :metadata, key: :kms_key, **lockbox_options
    has_encrypted :request_url, key: :kms_key, **lockbox_options
    has_encrypted :request_headers, key: :kms_key, **lockbox_options
    has_encrypted :request, key: :kms_key, **lockbox_options
    has_encrypted :response, key: :kms_key, **lockbox_options
  end
end
