class MoveEducationBenefitsToSavedClaims < ActiveRecord::Migration
  def change
    add_reference(:education_benefits_claims, :saved_claim, index: true)

    EducationBenefitsClaim.find_each do |education_benefits_claim|
      education_benefits_claim.build_saved_claim(
        form: education_benefits_claim.form,
        form_id: "22-#{education_benefits_claim.form_type.upcase}"
      )

      education_benefits_claim.save!
    end

    %w(submitted_at encrypted_form encrypted_form_iv form_type).each do |attr|
      remove_column(:education_benefits_claims, attr)
    end
  end
end
