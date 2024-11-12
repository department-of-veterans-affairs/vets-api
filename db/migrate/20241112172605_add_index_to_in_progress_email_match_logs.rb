class AddIndexToInProgressEmailMatchLogs < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :in_progress_email_match_logs, [:user_uuid, :in_progress_form_id], unique: true, algorithm: :concurrently
  end
end
