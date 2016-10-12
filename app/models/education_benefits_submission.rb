class EducationBenefitsSubmission < ActiveRecord::Base
  validates(:region, presence: true)
  validates(:region, inclusion: EducationForm::EducationFacility::REGIONS.map(&:to_s))
end
