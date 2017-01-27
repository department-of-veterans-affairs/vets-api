class CreateSerializedForms < ActiveRecord::Migration
  def change
    enable_extension 'uuid-ossp'
    create_table :serialized_forms do |t|
      t.uuid :user_uuid, null: false
      t.string :form_id, null: false
      t.string :encrypted_form_data, null: false
      t.string :encrypted_form_data_iv, null: false, :unique => true
      t.timestamps null: false
    end

    add_index(:serialized_forms, :user_uuid)
    add_index(:serialized_forms, :form_id)
  end
end
