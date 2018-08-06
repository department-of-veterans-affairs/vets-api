class AddStatusToDisabilityCompensationSubmissions < ActiveRecord::Migration
  change_table :disability_compensation_submissions do |t|
    t.string :status, default: 'submitted', null: false
    t.uuid :job_id
  end
end
