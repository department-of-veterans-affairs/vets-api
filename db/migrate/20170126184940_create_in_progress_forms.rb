class CreateInProgressForms < ActiveRecord::Migration
  safety_assured
  
  def change
    enable_extension 'uuid-ossp'
    create_table :in_progress_forms do |t|
      t.uuid :user_uuid, null: false
      t.string :form_id, null: false
      t.string :encrypted_form_data, null: false
      t.string :encrypted_form_data_iv, null: false, :unique => true
      t.timestamps null: false
    end

    add_index(:in_progress_forms, :user_uuid)
    add_index(:in_progress_forms, :form_id)
  end
end
