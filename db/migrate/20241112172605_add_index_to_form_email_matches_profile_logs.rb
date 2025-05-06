class AddIndexToFormEmailMatchesProfileLogs < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :form_email_matches_profile_logs,
              %i[user_uuid in_progress_form_id],
              unique: true,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
