class CreateDisabilityCompensationJobStatuses < ActiveRecord::Migration[4.2]
  def change
    create_table :disability_compensation_job_statuses do |t|
      t.integer :disability_compensation_submission_id, null: false
      t.string :job_id, unique: true, null: false
      t.string :job_class, null: false
      t.string :status, null: false
      t.string :error_message
      t.column :updated_at, :datetime, null: false
    end
  end
end
