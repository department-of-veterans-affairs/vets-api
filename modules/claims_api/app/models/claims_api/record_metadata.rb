# frozen_string_literal: true

module ClaimsApi
  # General purpose model for storing metadata associated with various records.
  # For example, a SOAP request that resulted in an error when establishing a Power of Attorney request.
  class RecordMetadata < ApplicationRecord
    has_kms_key
    has_encrypted :metadata, key: :kms_key, **lockbox_options

    # The actual metadata stored as text
    validates :metadata, presence: true
    # The type of record this metadata is associated with (e.g., 'PowerOfAttorney')
    validates :record_type, presence: true
    # The ID of the associated record
    validates :record_id, presence: true
  end
end
