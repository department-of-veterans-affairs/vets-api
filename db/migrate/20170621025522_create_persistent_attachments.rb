class CreatePersistentAttachments < ActiveRecord::Migration[4.2]
  def change
    create_table :persistent_attachments do |t|
      t.uuid :guid
      t.text :file_data
      t.string :type
      t.string :form_id

      t.timestamps null: false
      t.references :saved_claim
    end
  end
end
