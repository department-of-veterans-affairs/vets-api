class CreateForm526JobStatuses < ActiveRecord::Migration[4.2]
  def change
    create_table :form526_job_statuses do |t|
      t.integer :form526_submission_id, null: false
      t.string :job_id, unique: true, null: false
      t.string :job_class, null: false
      t.string :status, null: false
      t.string :error_class
      t.string :error_message
      t.column :updated_at, :datetime, null: false
    end
  end
end
