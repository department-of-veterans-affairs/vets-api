class CleanUpEducationBenefitsDataTransfer < ActiveRecord::Migration
  safety_assured

  def change
    remove_column(:saved_claims, :education_benefits_claim_id)

    EducationBenefitsClaim.where(saved_claim_id: nil).find_each do |education_benefits_claim|
      form_type = education_benefits_claim.read_attribute(:form_type)

      education_benefits_claim.saved_claim = SavedClaim::EducationBenefits.form_class(form_type).new(
        encrypted_form: education_benefits_claim.read_attribute(:encrypted_form),
        encrypted_form_iv: education_benefits_claim.read_attribute(:encrypted_form_iv)
      )

      education_benefits_claim.save!
    end

    change_column_null(:education_benefits_claims, :saved_claim_id, false)
  end
end
