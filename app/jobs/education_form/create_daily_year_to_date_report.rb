# frozen_string_literal: true
module EducationForm
  class CreateDailyYearToDateReport < ActiveJob::Base
    require 'csv'

    def calculate_submissions
      submissions = {}
      application_types = EducationBenefitsClaim::APPLICATION_TYPES

      EducationFacility::REGIONS.each do |region|
        region_submissions = {}
        this_year_range = @date.beginning_of_year..@date.end_of_year

        application_types.each do |application_type|
          region_submissions[application_type] = EducationBenefitsSubmission.where(
            created_at: this_year_range,
            region: region.to_s,
            application_type => true
          ).count
        end

        submissions[region] = region_submissions
      end

      submissions
    end

    def create_csv_header(csv_array)
      csv_array << ["Submitted Vets.gov Applications - Report FYTD #{@date.year} as of #{@date}"]
      csv_array << ['', '', 'DOCUMENT TYPE']
      csv_array << ['RPO', 'BENEFIT TYPE', '22-1990']
    end

    def create_csv_array
      submissions = calculate_submissions
      csv_array = []
      create_csv_header(csv_array)

      grand_total = 0

      submissions.each do |region, data|
        region_submissions_total = 0

        data.each_with_index do |(application_type, submissions_count), i|
          csv_array << [
            i.zero? ? EducationFacility::RPO_NAMES[region] : '',
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
      @date = date
      folder = 'tmp/daily_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@date}.csv"

      CSV.open(filename, 'wb') do |csv|
        create_csv_array.each do |row|
          csv << row
        end
      end

      if FeatureFlipper.send_email?
        # TODO set to deliver_later for production
        ReportMailer.year_to_date_report_email(File.read(filename)).deliver_now
      end

      # TODO: add rake task to cron
    end
  end
end
