class RemoveDisabilityCompensationSubmissions < ActiveRecord::Migration[5.2]
  def up
    drop_table :disability_compensation_submissions
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
