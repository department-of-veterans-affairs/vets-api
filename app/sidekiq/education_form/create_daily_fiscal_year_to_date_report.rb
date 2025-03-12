# frozen_string_literal: true

module EducationForm
  class CreateDailyFiscalYearToDateReport
    include Sidekiq::Job
    require 'csv'

    sidekiq_options(unique_for: 30.minutes)

    TOTALS_HASH = {
      yearly: 0,
      daily_submitted: 0,
      daily_processed: 0
    }.freeze

    FORM_TYPES = EducationBenefitsClaim::FORM_TYPES.reject do |form_type|
      %w[10282 10216 10215].include?(form_type)
    end.freeze

    FORM_TYPE_HEADERS = EducationBenefitsClaim.form_headers(FORM_TYPES).map do |form_header|
      [form_header, '', '']
    end.flatten.freeze

    OCTOBER = 10

    # use yesterday as the date for the daily job otherwise we will
    # miss applications that are submitted after the report is run
    def initialize(date = yesterday)
      @date = date
    end

    def yesterday
      Time.zone.today - 1.day
    end

    def beginning_of_fiscal_year
      # The beginning of the federal fiscal year is October 1st
      Date.new(fiscal_year - 1, OCTOBER)
    end

    def fiscal_year
      if @date.month < OCTOBER
        @date.year
      else
        @date.year + 1
      end
    end

    def build_submission_relation(range_type, region, form_type, status)
      range = @ranges[range_type]
      relation = EducationBenefitsSubmission.where(
        created_at: range,
        region: region.to_s,
        form_type:
      )
      relation = relation.where(status: 'processed') if status == :processed

      relation
    end

    def show_individual_benefits(form_type)
      %w[1990n 0993].exclude?(form_type)
    end

    def calculate_submissions(range_type: :year, status: :processed)
      submissions = {}
      application_types = EducationBenefitsClaim::APPLICATION_TYPES

      FORM_TYPES.each do |form_type|
        form_submissions = {}

        EducationFacility::REGIONS.each do |region|
          next if region_excluded(fiscal_year, region)

          relation = build_submission_relation(range_type, region, form_type, status)

          form_submissions[region] = build_region_submission(application_types, form_type, relation)
        end

        submissions[form_type] = form_submissions
      end

      submissions
    end

    def build_region_submission(application_types, form_type, relation)
      region_submissions = {}

      if show_individual_benefits(form_type)
        application_types.each do |application_type|
          region_submissions[application_type] = relation.where(application_type => true).count
        end
      else
        region_submissions[:all] = relation.count
      end

      region_submissions
    end

    def create_csv_header
      csv_array = []
      num_form_types = FORM_TYPES.size

      @ranges = {
        day: @date.all_day,
        year: beginning_of_fiscal_year..@date.end_of_day
      }

      ranges_header = [@ranges[:year].to_s, '', @ranges[:day].to_s]
      submitted_header = ['', 'Submitted', 'Sent to Spool File']

      csv_array << ["Submitted Vets.gov Applications - Report FYTD #{fiscal_year} as of #{@date}"]
      csv_array << ['', '', 'DOCUMENT TYPE']
      csv_array << (['RPO', 'BENEFIT TYPE'] + FORM_TYPE_HEADERS)
      csv_array << (['', ''] + (ranges_header * num_form_types))
      csv_array << (['', ''] + (submitted_header * num_form_types))

      csv_array
    end

    def create_data_row(on_last_index, application_type, region, submissions, submissions_total)
      row = []

      FORM_TYPES.each do |form_type|
        next row += ['', '', ''] if !show_individual_benefits(form_type) && !on_last_index

        TOTALS_HASH.each_key do |range_type|
          application_type_key = show_individual_benefits(form_type) ? application_type : :all
          num_submissions = submissions[range_type][form_type][region][application_type_key]
          row << num_submissions

          submissions_total[form_type][range_type] += num_submissions
        end
      end

      row
    end

    def create_csv_data_block(region, submissions, submissions_total)
      csv_array = []
      application_types = EducationBenefitsClaim::APPLICATION_TYPES

      application_types.each_with_index do |application_type, i|
        on_last_index = i == (application_types.size - 1)
        row = [
          i.zero? ? EducationFacility::RPO_NAMES[region] : '',
          application_type.humanize(capitalize: false)
        ]

        row += create_data_row(
          on_last_index,
          application_type,
          region,
          submissions,
          submissions_total
        )

        csv_array << row
      end

      csv_array
    end

    def create_totals_row(text_rows, totals)
      row = text_rows.clone

      FORM_TYPES.each do |form_type|
        TOTALS_HASH.each_key do |range_type|
          row << totals[form_type][range_type]
        end
      end

      row
    end

    def get_totals_hash_with_form_types
      totals = {}

      FORM_TYPES.each do |form_type|
        totals[form_type] = TOTALS_HASH.dup
      end

      totals
    end

    def convert_submissions_to_csv_array
      submissions_csv_array = []
      submissions = {
        yearly: calculate_submissions,
        daily_submitted: calculate_submissions(range_type: :day, status: :submitted),
        daily_processed: calculate_submissions(range_type: :day, status: :processed)
      }
      grand_totals = get_totals_hash_with_form_types

      EducationFacility::REGIONS.each do |region|
        next if region_excluded(fiscal_year, region)

        submissions_total = get_totals_hash_with_form_types

        submissions_csv_array += create_csv_data_block(region, submissions, submissions_total)

        submissions_csv_array << create_totals_row(['', 'TOTAL'], submissions_total)

        submissions_total.each do |form_type, form_submissions|
          form_submissions.each do |range_type, total|
            grand_totals[form_type][range_type] += total
          end
        end
      end

      submissions_csv_array << create_totals_row(['ALL RPOS TOTAL', ''], grand_totals)

      submissions_csv_array
    end

    def region_excluded(fiscal_year, region)
      # Atlanta is to be excluded from FYTD reports after the 2017 fiscal year
      return true if fiscal_year > 2017 && region == :southern
      # St. Louis is to be excluded from FYTD reports after the 2020 fiscal year
      return true if fiscal_year > 2020 && region == :central

      false
    end

    def create_csv_array
      csv_array = []

      csv_array += create_csv_header
      csv_array += convert_submissions_to_csv_array
      csv_array << (['', ''] + FORM_TYPE_HEADERS)

      csv_array
    end

    def generate_csv
      folder = 'tmp/daily_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@date}.csv"

      CSV.open(filename, 'wb') do |csv|
        create_csv_array.each do |row|
          csv << row
        end
      end

      filename
    end

    def perform
      filename = generate_csv
      return unless FeatureFlipper.send_edu_report_email?

      YearToDateReportMailer.build(filename).deliver_now
    end
  end
end
