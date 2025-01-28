class AddUserVerificationsToUserActions < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      change_column_null :user_actions, :subject_user_verification_id, false
      add_reference :user_actions, :acting_user_verification, foreign_key: { to_table: :user_verifications }
      remove_column :user_actions, :acting_user_account_id
      remove_column :user_actions, :subject_user_account_id
      remove_index :user_actions, :status
    end
  end

  def down
    safety_assured do
      change_column_null :user_actions, :subject_user_verification_id, true
      remove_column :user_actions, :acting_user_verification_id
      add_reference :user_actions, :acting_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      add_reference :user_actions, :subject_user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      add_index :user_actions, :status
    end
  end
end
