class AddUserAccountIdToFormEmailMatchesProfileLogs < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      add_reference :form_email_matches_profile_logs, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
