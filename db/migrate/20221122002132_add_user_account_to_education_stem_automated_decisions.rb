class AddUserAccountToEducationStemAutomatedDecisions < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_reference :education_stem_automated_decisions, :user_account, type: :uuid, foreign_key: true, null: true, index: true
    end
  end
end
