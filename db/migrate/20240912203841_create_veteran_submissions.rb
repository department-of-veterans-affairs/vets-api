class CreateVeteranSubmissions < ActiveRecord::Migration[7.1]
  def change
    create_table :veteran_submissions do |t|
      t.string :va_gov_submission_id
      t.string :va_gov_submission_type
      t.integer :status
      t.string :upstream_system_name
      t.string :upstream_submission_id

      t.timestamps
    end
  end
end
