class SubmissionChangesFor1995 < ActiveRecord::Migration
  safety_assured

  def up
    add_column(:education_benefits_submissions, :transfer_of_entitlement, :boolean, default: false, null: false)
    add_column(:education_benefits_submissions, :chapter1607, :boolean, default: false, null: false)
    # reload the model info so that it picks up the new column
    EducationBenefitsSubmission.reset_column_information
    EducationBenefitsSubmission.where(form_type: '1995').find_each do |education_benefits_submission|
      parsed_form = education_benefits_submission.education_benefits_claim&.parsed_form || {}
      benefit = parsed_form['benefit']&.underscore
      education_benefits_submission.update!(benefit => true) if benefit.present?
    end
  end

  def down
    remove_column(:education_benefits_submissions, :transfer_of_entitlement)
    remove_column(:education_benefits_submissions, :chapter1607)
  end
end
