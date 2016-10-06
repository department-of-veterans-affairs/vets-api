module EducationForm
  class CreateDailyYearToDateReport < ActiveJob::Base
    def get_submissions
      submissions = {}
      application_types = EducationBenefitsClaim::APPLICATION_TYPES

      EducationFacility::REGIONS.each do |region|
        region_submissions = {}
        application_types.each do |application_type|
          region_submissions[application_type] = 0
        end

        submissions[region] = region_submissions
      end

      EducationBenefitsClaim.find_each do |education_benefits_claim|
        region = education_benefits_claim.region

        application_types.each do |application_type|
          submissions[region][application_type] += 1 if education_benefits_claim.open_struct_form.public_send(application_type)
        end
      end

      submissions
    end

    def perform
    end
  end
end
