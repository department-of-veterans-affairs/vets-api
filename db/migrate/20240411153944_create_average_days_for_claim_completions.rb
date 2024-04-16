# This migration comes from vye (originally 20240229184515)
class CreateAverageDaysForClaimCompletions < ActiveRecord::Migration[7.1]
  def change
    create_table :average_days_for_claim_completions do |t|
      t.float :average_days

      t.timestamps
    end
  end
end
