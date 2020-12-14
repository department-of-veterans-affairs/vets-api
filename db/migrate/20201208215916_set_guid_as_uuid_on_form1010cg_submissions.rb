class SetGuidAsUuidOnForm1010cgSubmissions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    # Column and table are not yet in use. The model is not connected to ActiveRecord.
    safety_assured do
      remove_column :form1010cg_submissions, :claim_guid
      add_column :form1010cg_submissions, :claim_guid, :uuid, null: false
      add_index :form1010cg_submissions, :claim_guid, unique: true, algorithm: :concurrently
    end
  end

  def down
    remove_column :form1010cg_submissions, :claim_guid
    add_column :form1010cg_submissions, :claim_guid, :string, null: false
    add_index :form1010cg_submissions, :claim_guid, unique: true, algorithm: :concurrently
  end
end
