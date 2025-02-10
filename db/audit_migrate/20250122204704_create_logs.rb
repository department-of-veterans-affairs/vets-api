class CreateLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :logs do |t|
      t.string :subject_user_identifier, null: false, index: true
      t.string :subject_user_identifier_type, null: false
      t.string :acting_user_identifier, null: false, index: true
      t.string :acting_user_identifier_type, null: false
      t.string :event_description, null: false
      t.string :event_status, null: false
      t.datetime :event_occurred_at
      t.jsonb :message, null: false, default: {}
      t.timestamps
    end
  end
end
