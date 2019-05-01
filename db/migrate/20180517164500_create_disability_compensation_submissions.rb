class CreateDisabilityCompensationSubmissions < ActiveRecord::Migration[4.2]
  def change
    create_table :disability_compensation_submissions do |t|
      t.uuid :user_uuid, null: false
      t.string :form_type, null: false
      t.integer :claim_id, null: false, unique: true
      t.timestamps null: false
    end
  end
end
