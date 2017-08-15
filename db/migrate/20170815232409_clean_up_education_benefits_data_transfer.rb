class CleanUpEducationBenefitsDataTransfer < ActiveRecord::Migration
  def change
    remove_column(:saved_claims, :education_benefits_claim_id)

    change_column_null(:education_benefits_claims, :saved_claim_id, false)
  end
end
