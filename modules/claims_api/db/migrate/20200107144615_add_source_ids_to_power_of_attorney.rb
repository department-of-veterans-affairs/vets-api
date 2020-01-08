# frozen_string_literal: true

class AddSourceIdsToPowerOfAttorney < ActiveRecord::Migration[5.2]
  def change
    remove_column :claims_api_power_of_attorneys, :source, :string
    add_column :claims_api_power_of_attorneys, :encrypted_source_data, :string
    add_column :claims_api_power_of_attorneys, :encrypted_source_data_iv, :string
  end
end
