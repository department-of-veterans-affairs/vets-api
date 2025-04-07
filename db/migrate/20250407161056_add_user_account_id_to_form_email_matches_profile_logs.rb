class AddUserAccountIdToFormEmailMatchesProfileLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :form_email_matches_profile_logs, :user_account_id, :uuid, null: true
  end
end
