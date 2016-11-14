class AddStatusToEducationBenefitsSubmissions < ActiveRecord::Migration
  def change
    add_column(:education_benefits_submissions, :status, :string, null: false, default: 'submitted')
    EducationBenefitsSubmission.update_all(status: 'processed')

    add_column(:education_benefits_submissions, :education_benefits_claim_id, :integer)
    # don't know id for old submissions but it doesn't matter
    EducationBenefitsSubmission.update_all(education_benefits_claim_id: (EducationBenefitsClaim.first&.id || 1))
    change_column(:education_benefits_submissions, :education_benefits_claim_id, :integer, null: false)
  end
end
