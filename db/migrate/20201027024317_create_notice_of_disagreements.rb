class CreateNoticeOfDisagreements < ActiveRecord::Migration[6.0]
  def change
    enable_extension 'uuid-ossp'
    enable_extension 'pgcrypto'

    create_table :appeals_api_notice_of_disagreements, id: :uuid do |t|
      t.string :encrypted_form_data
      t.string :encrypted_form_data_iv
      t.string :encrypted_auth_headers
      t.string :encrypted_auth_headers_iv
      t.timestamps null: false
    end
  end
end
