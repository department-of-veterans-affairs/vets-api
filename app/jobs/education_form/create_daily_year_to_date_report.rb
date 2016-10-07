module EducationForm
  class CreateDailyYearToDateReport < ActiveJob::Base
    require 'csv'

    def get_submissions(date)
      submissions = {}
      application_types = EducationBenefitsClaim::APPLICATION_TYPES

      EducationFacility::REGIONS.each do |region|
        region_submissions = {}
        application_types.each do |application_type|
          region_submissions[application_type] = 0
        end

        submissions[region] = region_submissions
      end

      EducationBenefitsClaim.where(submitted_at: date.beginning_of_year..date.end_of_year).find_each do |education_benefits_claim|
        region = education_benefits_claim.region

        application_types.each do |application_type|
          submissions[region][application_type] += 1 if education_benefits_claim.open_struct_form.public_send(application_type)
        end
      end

      submissions
    end

    def create_csv_array(date)
      submissions = get_submissions(date)
      csv_array = []

      csv_array << ["Submitted Vets.gov Applications - Report FYTD #{date.year} as of #{date}"]

      csv_array << ['', '', 'DOCUMENT TYPE']
      csv_array << ['RPO', 'BENEFIT TYPE', '22-1990']

      grand_total = 0

      submissions.each do |region, data|
        region_submissions_total = 0

        data.each_with_index do |(application_type, submissions_count), i|
          csv_array << [
            i == 0 ? EducationFacility::RPO_NAMES[region] : '',
            application_type,
            submissions_count
          ]
          region_submissions_total += submissions_count
        end

        csv_array << ['', 'TOTAL', region_submissions_total]
        grand_total += region_submissions_total
      end

      csv_array << ['ALL RPOS TOTAL', '', grand_total]
      csv_array << ['', '', '22-1990']

      csv_array
    end

    def perform(date)
      folder = 'tmp/daily_reports'
      FileUtils.mkdir_p(folder)

      CSV.open("#{folder}/#{date}.csv", 'wb') do |csv|
        create_csv_array(date).each do |row|
          csv << row
        end
      end

      # TODO: email the csv file
    end
  end
end
