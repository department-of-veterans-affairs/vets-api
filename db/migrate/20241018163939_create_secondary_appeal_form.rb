class CreateSecondaryAppealForm < ActiveRecord::Migration[7.1]
  def change
    create_table :secondary_appeal_forms do |t|
      t.string :form_id
      t.text :encrypted_kms_key
      t.text :form_ciphertext
      t.uuid :guid
      t.string :status
      t.datetime :status_updated_at
      t.references :appeal_submission
      t.datetime :delete_date

      t.timestamps
    end
  end
end
