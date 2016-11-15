# frozen_string_literal: true
module EducationForm
  class CreateDailyYearToDateReport
    include Sidekiq::Worker
    require 'csv'

    def calculate_submissions(range_type: :year, status: :processed)
      submissions = {}
      application_types = EducationBenefitsClaim::APPLICATION_TYPES
      range = @date.public_send("beginning_of_#{range_type}")..@date.end_of_day

      EducationFacility::REGIONS.each do |region|
        region_submissions = {}

        application_types.each do |application_type|
          relation = EducationBenefitsSubmission.where(
            created_at: range,
            region: region.to_s,
            application_type => true
          )
          relation = relation.where(status: 'processed') if status == :processed
          region_submissions[application_type] = relation.count
        end

        submissions[region] = region_submissions
      end

      submissions
    end

    def create_csv_header(csv_array)
      csv_array << ["Submitted Vets.gov Applications - Report FYTD #{@date.year} as of #{@date}"]
      csv_array << ['', '', 'DOCUMENT TYPE']
      csv_array << ['RPO', 'BENEFIT TYPE', '22-1990']
      csv_array << ['', '', @date.year, '', @date.to_s]
      csv_array << ['', '', '', 'Submitted', 'Uploaded to TIMS']
    end

    def create_csv_array
      submissions = calculate_submissions
      daily_submitted = calculate_submissions(range_type: :day, status: :submitted)
      daily_processed = calculate_submissions(range_type: :day, status: :processed)
      csv_array = []
      create_csv_header(csv_array)

      grand_totals = {
        yearly: 0,
        daily_submitted: 0,
        daily_processed: 0
      }

      submissions.each do |region, data|
        submissions_total = {
          yearly: 0,
          daily_submitted: 0,
          daily_processed: 0
        }

        data.each_with_index do |(application_type, yearly_processed_count), i|
          daily_submitted_count = daily_submitted[region][application_type]
          daily_processed_count = daily_processed[region][application_type]

          csv_array << [
            i.zero? ? EducationFacility::RPO_NAMES[region] : '',
            application_type,
            yearly_processed_count,
            daily_submitted_count,
            daily_processed_count
          ]

          submissions_total[:yearly] += yearly_processed_count
          submissions_total[:daily_submitted] += daily_submitted_count
          submissions_total[:daily_processed] += daily_processed_count
        end

        csv_array << ['', 'TOTAL', submissions_total[:yearly], submissions_total[:daily_submitted], submissions_total[:daily_processed]]

        grand_totals.each do |type, _|
          grand_totals[type] += submissions_total[type]
        end
      end

      csv_array << ['ALL RPOS TOTAL', '', grand_totals[:yearly], grand_totals[:daily_submitted], grand_totals[:daily_processed]]
      csv_array << ['', '', '22-1990']

      csv_array
    end

    def perform
      # use yesterday as the date otherwise we will miss applications that are submitted after the report is run
      @date = Time.zone.today - 1.day
      folder = 'tmp/daily_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@date}.csv"

      CSV.open(filename, 'wb') do |csv|
        create_csv_array.each do |row|
          csv << row
        end
      end

      return unless FeatureFlipper.send_email?
      YearToDateReportMailer.build(filename).deliver_now
    end
  end
end
