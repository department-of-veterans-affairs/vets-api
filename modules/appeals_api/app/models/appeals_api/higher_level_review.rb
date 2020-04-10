# frozen_string_literal: true

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: { pending: 0, submitted: 1, established: 2, errored: 3 }

    def receipt_date
      Date.parse(
        form_data_receipt_date ||
        created_at&.strftime('%F') ||
        Time.now.utc.strftime('%F')
      )
    end

    private

    def form_data_receipt_date
      form_data&.dig('data', 'attributes', 'receiptDate')
    end
  end
end
