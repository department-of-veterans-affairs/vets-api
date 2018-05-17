class CreateDisabilityCompensationSubmissions < ActiveRecord::Migration
  def change
    create_table :disability_compensation_submissions do |t|
      t.uuid :user_uuid, null: false
      t.string :form_id, null: false
      t.string :claim_id, null: false
      t.timestamps null: false
    end
  end
end
