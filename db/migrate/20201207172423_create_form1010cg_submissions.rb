class CreateForm1010cgSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :form1010cg_submissions do |t|
      # Salesforce record IDs are 15 or 18 characters long
      # The 18 digit ID is case insensitive whereas the 15 digit ID is case sensitive
      t.string :carma_case_id, null: false, limit: 18
      t.datetime :accepted_at, null: false
      t.string :claim_guid, null: false
      t.json :metadata
      t.json :attachments

      t.timestamps null: false
    end
  end
end
