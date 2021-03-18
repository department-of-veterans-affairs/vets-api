# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class EvidenceSubmission < ApplicationRecord
    belongs_to :supportable, polymorphic: true

    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
  end
end
