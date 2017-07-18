class MoveEducationBenefitsToSavedClaims < ActiveRecord::Migration
  def change
    remove_column(:education_benefits_claims, :submitted_at)
    add_reference(:education_benefits_claims, :saved_claim, index: true)

    EducationBenefitsClaim.find_each do |education_benefits_claim|
      education_benefits_claim.build_saved_claim(
        form: education_benefits_claim.form,
        form_id: "22-#{education_benefits_claim.form_type.upcase}"
      )

      education_benefits_claim.save!
    end

    binding.pry; fail
  end
end
