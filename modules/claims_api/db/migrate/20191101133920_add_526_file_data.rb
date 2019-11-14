# frozen_string_literal: true

class Add526FileData < ActiveRecord::Migration[5.2]
  def change
    add_column :claims_api_auto_established_claims, :encrypted_file_data, :string
    add_column :claims_api_auto_established_claims, :encrypted_file_data_iv, :string
  end
end
