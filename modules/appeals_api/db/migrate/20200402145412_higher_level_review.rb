# frozen_string_literal: true

class HigherLevelReview < ActiveRecord::Migration[5.2]
  def change
    enable_extension 'uuid-ossp'
    enable_extension 'pgcrypto'

    create_table :appeals_api_higher_level_reviews, id: :uuid do |t|
      t.integer :status, default: 0
      t.string :encrypted_form_data
      t.string :encrypted_form_data_iv
      t.string :encrypted_auth_headers
      t.string :encrypted_auth_headers_iv
      t.timestamps null: false
    end
  end
end
