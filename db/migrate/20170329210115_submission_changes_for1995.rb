class SubmissionChangesFor1995 < ActiveRecord::Migration
  def change
    %w(transfer_of_entitlement chapter1607).each do |benefit|
      add_column(:education_benefits_submissions, benefit, :boolean, default: false, null: false)
    end

    # reload the model info so that it picks up the new column
    EducationBenefitsSubmission.reset_column_information
    EducationBenefitsSubmission.where(form_type: '1995').find_each do |education_benefits_submission|
      parsed_form = education_benefits_submission.education_benefits_claim&.parsed_form || {}
      benefit = parsed_form['benefit']&.underscore
      education_benefits_submission.update!(benefit => true) if benefit.present?
    end
  end
end
