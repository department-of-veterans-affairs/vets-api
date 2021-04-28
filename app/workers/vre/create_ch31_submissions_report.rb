# frozen_string_literal: true

module VRE
  class CreateCh31SubmissionsReport
    require 'csv'
    include Sidekiq::Worker

    def updated_at_range
      (@time - 24.hours)..(@time - 1.second)
    end

    def get_claims_submitted_in_range
      SavedClaim::VeteranReadinessEmploymentClaim.where(
        updated_at: updated_at_range
      )
    end

    def create_csv_array(submitted_claims)
      data = { csv_array: [] }
      data[:csv_array] << ['Count', 'Regional Office', 'PID', 'Date Application Received', 'Type of Form', 'Total']

      total = submitted_claims.size
      submitted_claims.find_each.with_index do |veteran_readiness_employment_claim, index|
        parsed_form = veteran_readiness_employment_claim.parsed_form

        data[:csv_array] << [
          index + 1,
          parsed_form['veteranInformation']['regionalOffice'],
          parsed_form['veteranInformation']['pid'],
          veteran_readiness_employment_claim.updated_at.to_s,
          veteran_readiness_employment_claim.form_id,
          total
        ]
      end
      data
    end

    def perform
      @time = Time.zone.now
      folder = 'tmp/ch31_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@time.to_date}.csv"
      submitted_claims = get_claims_submitted_in_range
      csv_array_data = create_csv_array(submitted_claims)
      csv_array = csv_array_data[:csv_array]
      CSV.open(filename, 'wb') do |csv|
        csv_array.each do |row|
          csv << row
        end
      end

      Ch31SubmissionsReportMailer.build(filename).deliver_now
    end
  end
end
