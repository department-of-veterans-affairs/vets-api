class RemoveDisabilityCompensationJobStatuses < ActiveRecord::Migration[5.2]
  def up
    drop_table :disability_compensation_job_statuses
  end

  def down
    create_table "disability_compensation_job_statuses", id: :serial, force: :cascade do |t|
      t.integer "disability_compensation_submission_id", null: false
      t.string "job_id", null: false
      t.string "job_class", null: false
      t.string "status", null: false
      t.string "error_message"
      t.datetime "updated_at", null: false
      t.index ["disability_compensation_submission_id"], name: "index_disability_compensation_job_statuses_on_dsc_id"
      t.index ["job_id"], name: "index_disability_compensation_job_statuses_on_job_id", unique: true
    end
  end
end
