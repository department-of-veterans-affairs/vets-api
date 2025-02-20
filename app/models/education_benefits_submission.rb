# frozen_string_literal: true

class EducationBenefitsSubmission < ApplicationRecord
  # don't delete this table, we need to keep the data for a report
  validates(:region, presence: true)
  validates(:region, inclusion: EducationForm::EducationFacility::REGIONS.map(&:to_s))
  validates(:status, inclusion: %w[processed submitted])
  validates(:form_type, inclusion: EducationBenefitsClaim::FORM_TYPES)

  belongs_to(:education_benefits_claim, inverse_of: :education_benefits_submission)
end
