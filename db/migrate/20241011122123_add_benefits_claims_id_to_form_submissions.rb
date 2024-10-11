class AddBenefitsClaimsIdToFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    add_column :form_submissions, :benefits_claims_id, :string
  end
end
