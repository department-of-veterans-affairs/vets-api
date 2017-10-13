class SetupEduBenefitsMigration < ActiveRecord::Migration
  def change
    add_reference(:education_benefits_claims, :saved_claim, index: true)
    add_column(:saved_claims, :education_benefits_claim_id, :integer)
  end
end
