class MoveEducationBenefitsToSavedClaims < ActiveRecord::Migration
  def change
    add_reference(:education_benefits_claims, :saved_claim, index: true)

    EducationBenefitsClaim.find_each do |education_benefits_claim|
      form_type = education_benefits_claim.read_attribute(:form_type)

      education_benefits_claim.saved_claim = SavedClaim::EducationBenefits.form_class(form_type).new(
        encrypted_form: education_benefits_claim.read_attribute(:encrypted_form),
        encrypted_form_iv: education_benefits_claim.read_attribute(:encrypted_form_iv)
      )

      education_benefits_claim.save!
    end

    change_column_null(:education_benefits_claims, :saved_claim_id, false)

    %w(submitted_at encrypted_form encrypted_form_iv form_type).each do |attr|
      remove_column(:education_benefits_claims, attr)
    end

    add_index(:education_benefits_claims, :created_at)
  end
end
