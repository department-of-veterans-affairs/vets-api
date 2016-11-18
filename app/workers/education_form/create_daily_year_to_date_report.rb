# frozen_string_literal: true
module EducationForm
  class CreateDailyYearToDateReport
    include Sidekiq::Worker
    require 'csv'

    TOTALS_HASH = {
      yearly: 0,
      daily_submitted: 0,
      daily_processed: 0
    }.freeze

    def calculate_submissions(range_type: :year, status: :processed)
      submissions = {}
      application_types = EducationBenefitsClaim::APPLICATION_TYPES
      range = @ranges[range_type]

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

    def create_csv_header
      csv_array = []

      @ranges = {}
      %i(day year).each do |range_type|
        @ranges[range_type] = @date.public_send("beginning_of_#{range_type}")..@date.end_of_day
      end

      csv_array << ["Submitted Vets.gov Applications - Report FYTD #{@date.year} as of #{@date}"]
      csv_array << ['', '', 'DOCUMENT TYPE']
      csv_array << ['RPO', 'BENEFIT TYPE', '22-1990']
      csv_array << ['', '', @date.year, '', @date.to_s]
      csv_array << ['', '', '', 'Submitted', 'Uploaded to TIMS']

      csv_array
    end

    def create_csv_data_row(regional_yearly_submissions, region, submissions, submissions_total)
      csv_array = []

      regional_yearly_submissions.each_with_index do |(application_type, yearly_processed_count), i|
        daily_submitted_count = submissions[:daily_submitted][region][application_type]
        daily_processed_count = submissions[:daily_processed][region][application_type]

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

      csv_array
    end

    def create_totals_row(text_rows, totals)
      row = text_rows.clone

      row << totals[:yearly]
      row << totals[:daily_submitted]
      row << totals[:daily_processed]

      row
    end

    def convert_submissions_to_csv_array
      submissions_csv_array = []
      submissions = {
        yearly: calculate_submissions,
        daily_submitted: calculate_submissions(range_type: :day, status: :submitted),
        daily_processed: calculate_submissions(range_type: :day, status: :processed)
      }
      grand_totals = TOTALS_HASH.dup

      submissions[:yearly].each do |region, regional_yearly_submissions|
        submissions_total = TOTALS_HASH.dup
        data_row = create_csv_data_row(regional_yearly_submissions, region, submissions, submissions_total)
        submissions_csv_array += data_row

        submissions_csv_array << create_totals_row(['', 'TOTAL'], submissions_total)

        grand_totals.each { |t, _| grand_totals[t] += submissions_total[t] }
      end

      submissions_csv_array << create_totals_row(['ALL RPOS TOTAL', ''], grand_totals)

      submissions_csv_array
    end

    def create_csv_array
      csv_array = []

      csv_array += create_csv_header
      csv_array += convert_submissions_to_csv_array
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
