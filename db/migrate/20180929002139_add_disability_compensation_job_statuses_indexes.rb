class AddDisabilityCompensationJobStatusesIndexes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(
      :disability_compensation_job_statuses,
      :disability_compensation_submission_id,
      algorithm: :concurrently, name: 'index_disability_compensation_job_statuses_on_dcs_id'
    )
    add_index(:disability_compensation_job_statuses, :job_id, unique: true, algorithm: :concurrently)
  end
end
