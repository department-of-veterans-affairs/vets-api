class AddUserAccountToForm526Submissions < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_reference :form526_submissions, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
