class ValidateUserActionsForeignKeys < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :user_actions, :user_accounts, column: :acting_user_account_id
    validate_foreign_key :user_actions, :user_accounts, column: :subject_user_account_id
    validate_foreign_key :user_actions, :user_action_events
  end
end 