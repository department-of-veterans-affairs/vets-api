class RemoveDisabilityCompensationJobStatuses < ActiveRecord::Migration[5.2]
  def up
    drop_table :disability_compensation_job_statuses
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
