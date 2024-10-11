class AddBenefitsClaimsIndexToFormSubmissions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  
  def change
    add_index :form_submissions, :benefits_claims_id, algorithm: :concurrently, if_not_exists: true
  end
end
