class CreateForm526SubmissionRemediations < ActiveRecord::Migration[7.1]
  def change
    create_table :form526_submission_remediations do |t|
      t.references :form526_submission, null: false, foreign_key: true
      t.text :lifecycle, array: true, default: []
      t.boolean :success, default: true
      t.boolean :ignored_as_duplicate, default: false

      t.timestamps      
    end
  end
end
