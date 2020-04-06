# frozen_string_literal: true

module AppealsApi
  class HigherLevelReviewSubmission < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: [ :pending, :submitted, :established, :errored ]
  end
end
