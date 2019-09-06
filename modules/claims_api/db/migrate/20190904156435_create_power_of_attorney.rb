# frozen_string_literal: true

class CreatePowerOfAttorney < ActiveRecord::Migration
    def change
      enable_extension 'uuid-ossp'
  
      create_table :claims_api_power_of_attorney, id: :uuid do |t|
        t.string :status
        t.string :encrypted_form_data
        t.string :encrypted_form_data_iv
        t.string :encrypted_auth_headers
        t.string :encrypted_auth_headers_iv
        t.string :md5
        t.string :source
  
        t.timestamps null: false
      end
    end
  end