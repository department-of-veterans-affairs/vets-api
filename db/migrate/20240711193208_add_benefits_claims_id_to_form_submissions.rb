class AddBenefitsClaimsIdToFormSubmissions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  
  def change
    add_column :form_submissions, :benefits_claims_id, :string
    add_index :form_submissions, :benefits_claims_id, algorithm: :concurrently
  end
end
