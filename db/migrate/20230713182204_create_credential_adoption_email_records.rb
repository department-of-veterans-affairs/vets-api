class CreateCredentialAdoptionEmailRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :credential_adoption_email_records do |t|
      t.string :icn, null: false
      t.string :email_address, null: false
      t.string :email_template_id, null: false
      t.datetime :email_triggered_at

      t.timestamps

      t.index :icn
      t.index :email_address
      t.index :email_template_id
    end
  end
end