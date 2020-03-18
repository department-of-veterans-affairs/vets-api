class RemoveDisabilityCompensationJobStatuses < ActiveRecord::Migration[5.2]
  def change
    drop_table :disability_compensation_job_statuses
  end
end
