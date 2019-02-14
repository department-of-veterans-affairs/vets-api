# frozen_string_literal: true

class CreateAutoEstablishedClaims < ActiveRecord::Migration
  def change
    create_table :claims_api_auto_established_claims do |t|
      t.string :status
      t.string :form_data_encrypted
      t.string :form_data_encrypted_iv
      t.string :auth_headers_encrypted
      t.string :auth_headers_encrypted_iv
      t.integer :evss_id

      t.timestamps null: false
    end
  end
end
