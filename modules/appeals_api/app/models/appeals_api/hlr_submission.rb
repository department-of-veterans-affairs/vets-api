# frozen_string_literal: true

module AppealsApi
  class HlrSubmission < ApplicationRecord
    attr_encrypted(:json, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:pdf, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: [ :pending, :submitted, :established, :errored ]
  end
end
