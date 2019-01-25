class SubmissionChangesFor0994 < ActiveRecord::Migration
  def add
    add_column(:education_benefits_submissions, :vettec, :boolean, default: false, null: false)
    EducationBenefitsSubmission.update_all(vettec: false)
  end
end
