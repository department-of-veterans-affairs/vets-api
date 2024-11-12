class CreateInProgressEmailMatchLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :in_progress_email_match_logs do |t|
      t.string :user_uuid, null: false
      t.integer :in_progress_form_id, null: false
      t.timestamps
    end

    # Add a unique index to enforce uniqueness on the user/form combination
    add_index :in_progress_email_match_logs, [:user_uuid, :in_progress_form_id], unique: true
  end
end
