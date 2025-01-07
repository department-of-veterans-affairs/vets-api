class CreateFormEmailMatchesProfileLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :form_email_matches_profile_logs do |t|
      t.string :user_uuid, null: false
      t.integer :in_progress_form_id, null: false
      t.timestamps
    end
  end
end
