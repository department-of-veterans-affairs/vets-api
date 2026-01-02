# frozen_string_literal: true

class AddDetailsToRecordMetadata < ActiveRecord::Migration[7.2]
  def change
    add_column :claims_api_record_metadata, :request_url_ciphertext, :string
    add_column :claims_api_record_metadata, :request_ciphertext, :text
    add_column :claims_api_record_metadata, :response_ciphertext, :text
    add_column :claims_api_record_metadata, :request_headers_ciphertext, :text
  end
end
