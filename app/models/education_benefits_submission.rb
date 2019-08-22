# frozen_string_literal: true

class EducationBenefitsSubmission < ApplicationRecord
  # don't delete this table, we need to keep the data for a report
  validates(:region, :education_benefits_claim, presence: true)
  validates(:region, inclusion: EducationForm::EducationFacility::REGIONS.map(&:to_s))
  validates(:status, inclusion: %w[processed submitted])
  validates(:form_type, inclusion: EducationBenefitsClaim::FORM_TYPES)

  belongs_to(:education_benefits_claim, inverse_of: :education_benefits_submission)

  def benefit_form_type
    form_type == '1995' && stem ? 'stem1995' : form_type
  end
end
