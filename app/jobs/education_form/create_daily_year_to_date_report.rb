module EducationForm
  class CreateDailyYearToDateReport < ActiveJob::Base
    def perform
      submissions = {}

      EducationFacility::REGIONS.each do |region|
        region_submissions = {}
        EducationBenefitsClaim::APPLICATION_TYPES.each do |application_type|
          region_submissions[application_type] = 0
        end

        submissions[region] = region_submissions
      end

      EducationBenefitsClaim.find_each do |education_benefits_claim|
      end
    end
  end
end
