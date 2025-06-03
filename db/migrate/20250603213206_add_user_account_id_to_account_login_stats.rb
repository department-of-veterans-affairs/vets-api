class AddUserAccountIdToAccountLoginStats < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      add_reference :account_login_stats, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
