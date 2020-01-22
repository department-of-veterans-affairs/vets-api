# frozen_string_literal: true

class AddHeadersMd5 < ActiveRecord::Migration[5.2]
  safety_assured

  def change
    add_column :claims_api_power_of_attorneys, :header_md5, :string
    add_index :claims_api_power_of_attorneys, :header_md5
  end
end
