class CreateForm526JobStatusesIndexes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:form526_job_statuses, :form526_submission_id, algorithm: :concurrently)
    add_index(:form526_job_statuses, :job_id, unique: true, algorithm: :concurrently)
  end
end
