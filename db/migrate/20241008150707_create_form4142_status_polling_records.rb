class CreateForm4142StatusPollingRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :form4142_status_polling_records do |t|
      t.string :benefits_intake_uuid
      t.integer :submission_id
      t.integer :status

      t.timestamps
    end
  end
end
