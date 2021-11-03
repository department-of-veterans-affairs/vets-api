class AddErrorsToForm526JobStatuses < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      change_table :form526_job_statuses do |t|
        t.jsonb :bgjob_errors, default: {}
      end

      add_index :form526_job_statuses, :bgjob_errors, using: :gin
    end
  end
end
