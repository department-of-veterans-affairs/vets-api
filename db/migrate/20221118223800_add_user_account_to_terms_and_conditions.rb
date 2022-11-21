class AddUserAccountToTermsAndConditions < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_reference :terms_and_conditions_acceptances, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
