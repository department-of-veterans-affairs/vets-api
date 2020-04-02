# frozen_string_literal: true

class HlrSubmission < ActiveRecord::Migration[5.2]
  def change
    enable_extension 'uuid-ossp'
    enable_extension 'pgcrypto'

    create_table :hlr_submissions, id: :uuid do |t|
      t.integer :status, default: 0
      t.string :encrypted_json
      t.string :encrypted_json_iv
      t.string :encrypted_headers
      t.string :encrypted_headers_iv
      t.string :encrypted_pdf
      t.string :encrypted_pdf_iv
      t.timestamps null: false
    end
  end
end
