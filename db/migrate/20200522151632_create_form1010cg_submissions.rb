class CreateForm1010cgSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :form1010cg_submissions do |t|
      # Salesforce record IDs are 15 or 18 characters long
      # The 18 digit ID is case insensitive where as the 15 digit ID is case sensitive
      t.string :carma_case_id, null: false, limit: 18
      t.datetime :submitted_at, null: false
      t.references :saved_claim, null: false, foreign_key: true, index: { unique: true }

      t.timestamps null: false
    end
  end
end
