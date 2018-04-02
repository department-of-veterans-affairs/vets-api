# frozen_string_literal: true

module EducationForm
  class CreateSpoolSubmissionsReport
    require 'csv'
    include Sidekiq::Worker

    def format_name(full_name)
      return if full_name.blank?

      [full_name['first'], full_name['last']].compact.join(' ')
    end

    def processed_at_range
      (@time - 24.hours)..@time
    end

    def create_csv_array
      csv_array = []
      csv_array << ['Claimant Name', 'Veteran Name', 'Confirmation #', 'Time Submitted', 'RPO']

      EducationBenefitsClaim.where(
        processed_at: processed_at_range
      ).find_each do |education_benefits_claim|
        parsed_form = education_benefits_claim.parsed_form

        csv_array << [
          format_name(parsed_form['relativeFullName']),
          format_name(parsed_form['veteranFullName']),
          education_benefits_claim.confirmation_number,
          education_benefits_claim.processed_at.to_s,
          education_benefits_claim.regional_processing_office
        ]
      end

      csv_array
    end

    def perform
      Sentry::TagRainbows.tag
      @time = Time.zone.now
      folder = 'tmp/spool_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@time.to_date}.csv"

      CSV.open(filename, 'wb') do |csv|
        create_csv_array.each do |row|
          csv << row
        end
      end

      return unless FeatureFlipper.send_email?
      SpoolSubmissionsReportMailer.build(filename).deliver_now
    end
  end
end
