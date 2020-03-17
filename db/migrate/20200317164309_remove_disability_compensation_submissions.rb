class RemoveDisabilityCompensationSubmissions < ActiveRecord::Migration[5.2]
  def up
    drop_table :disability_compensation_submissions
  end

  def down
    fail ActiveRecord::IrreversibleMigration
  end
end
