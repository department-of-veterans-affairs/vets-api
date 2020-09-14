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
      data = {
        csv_array: [],
        stem_exists: false
      }
      data[:csv_array] << ['Claimant Name', 'Veteran Name', 'Confirmation #', 'Time Submitted', 'RPO']

      EducationBenefitsClaim.where(
        processed_at: processed_at_range
      ).find_each do |education_benefits_claim|
        parsed_form = education_benefits_claim.parsed_form
        data[:stem_exists] = data[:stem_exists]
        data[:csv_array] << [
          format_name(parsed_form['relativeFullName']),
          format_name(parsed_form['veteranFullName']),
          education_benefits_claim.confirmation_number,
          education_benefits_claim.processed_at.to_s,
          education_benefits_claim.regional_processing_office
        ]
      end
      data
    end

    def perform
      @time = Time.zone.now
      folder = 'tmp/spool_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@time.to_date}.csv"
      csv_array_data = create_csv_array
      stem_exists = csv_array_data[:stem_exists]
      csv_array = csv_array_data[:csv_array]
      CSV.open(filename, 'wb') do |csv|
        csv_array.each do |row|
          csv << row
        end
      end

      return unless FeatureFlipper.send_edu_report_email?

      SpoolSubmissionsReportMailer.build(filename, stem_exists).deliver_now
    end
  end
end
