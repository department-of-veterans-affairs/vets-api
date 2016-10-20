# frozen_string_literal: true
class EducationBenefitsSubmission < ActiveRecord::Base
  # don't delete this table, we need to keep the data for a report
  validates(:region, presence: true)
  validates(:region, inclusion: EducationForm::EducationFacility::REGIONS.map(&:to_s))
end
