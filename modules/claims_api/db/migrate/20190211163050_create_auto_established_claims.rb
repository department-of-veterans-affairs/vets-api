# frozen_string_literal: true

class CreateAutoEstablishedClaims < ActiveRecord::Migration
  def change
    enable_extension 'uuid-ossp'

    create_table :claims_api_auto_established_claims, id: :uuid do |t|
      t.string :status
      t.string :encrypted_form_data
      t.string :encrypted_form_data_iv
      t.string :encrypted_auth_headers
      t.string :encrypted_auth_headers_iv
      t.integer :evss_id

      t.timestamps null: false
    end
  end
end
