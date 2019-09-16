# frozen_string_literal: true

desc 'update all records in education_benefits_submissions table'
task education_benefits_submission: :environment do
  # `update_all` is being used because the `vettec` field will reset to `false`
  # as the form isn't live on staging and prod
  EducationBenefitsSubmission.update_all(vettec: false)
end
