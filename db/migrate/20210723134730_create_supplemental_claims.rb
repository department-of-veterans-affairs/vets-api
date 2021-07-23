class CreateSupplementalClaims < ActiveRecord::Migration[6.1]
  def change
    enable_extension 'uuid-ossp'
    enable_extension 'pgcrypto'

    create_table :appeals_api_supplemental_claims, id: :uuid do |t|
      t.string :encrypted_form_data
      t.string :encrypted_form_data_iv
      t.string :encrypted_auth_headers
      t.string :encrypted_auth_headers_iv
      t.string :status, default: 'pending'
      t.string :code
      t.string :detail
      t.string :source
      t.string :pdf_version
      t.string :api_version

      t.timestamps null: false
    end
  end
end
