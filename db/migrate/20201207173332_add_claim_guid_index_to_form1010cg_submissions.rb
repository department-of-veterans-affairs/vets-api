class AddClaimGuidIndexToForm1010cgSubmissions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :form1010cg_submissions, :claim_guid, unique: true, algorithm: :concurrently
  end
end
