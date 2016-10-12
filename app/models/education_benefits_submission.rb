class EducationBenefitsSubmission < ActiveRecord::Base
  validates(:region, presence: true)
end
