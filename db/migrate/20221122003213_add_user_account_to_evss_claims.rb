class AddUserAccountToEVSSClaims < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_reference :evss_claims, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
