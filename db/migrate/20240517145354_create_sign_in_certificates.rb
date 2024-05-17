class CreateSignInCertificates < ActiveRecord::Migration[7.1]
  def change
    create_table :sign_in_certificates do |t|
      t.string :issuer, null: false
      t.string :subject, null: false
      t.string :serial, null: false
      t.datetime :not_before, null: false
      t.datetime :not_after, null: false
      t.text :plaintext, null: false
      t.references :client_config, foreign_key: true, null: true, index: true
      t.references :service_account_config, foreign_key: true, null: true, index: true

      t.timestamps
    end
  end
end
