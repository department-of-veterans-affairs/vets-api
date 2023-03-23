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

    FORM_TYPES = EducationBenefitsClaim::FORM_TYPES

    FORM_TYPE_HEADERS = EducationBenefitsClaim.form_headers(FORM_TYPES).map do |form_header|
      [form_header, '', '']
    end.flatten.freeze

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
          region_submissions = {}

          relation = build_submission_relation(range_type, region, form_type, status)

          if show_individual_benefits(form_type)
            application_types.each do |application_type|
              region_submissions[application_type] = relation.where(application_type => true).count
            end
          else
            region_submissions[:all] = relation.count
          end

          form_submissions[region] = region_submissions
        end

        submissions[form_type] = form_submissions
      end

      submissions
    end

    def create_csv_header
      csv_array = []
      num_form_types = FORM_TYPES.size

      @ranges = {}
      %i[day year].each do |range_type|
        @ranges[range_type] = @date.public_send("beginning_of_#{range_type}")..@date.end_of_day
      end

      ranges_header = [@ranges[:year].to_s, '', @ranges[:day].to_s]
      submitted_header = ['', 'Submitted', 'Sent to Spool File']

      csv_array << ["Submitted Vets.gov Applications - Report FYTD #{@date.year} as of #{@date}"]
      csv_array << ['', '', 'DOCUMENT TYPE']
      csv_array << ['RPO', 'BENEFIT TYPE'] + FORM_TYPE_HEADERS
      csv_array << ['', ''] + ranges_header * num_form_types
      csv_array << ['', ''] + submitted_header * num_form_types

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

    def create_csv_array
      csv_array = []

      csv_array += create_csv_header
      csv_array += convert_submissions_to_csv_array
      csv_array << ['', ''] + FORM_TYPE_HEADERS

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

      return unless FeatureFlipper.send_edu_report_email?

      YearToDateReportMailer.build(filename).deliver_now
    end
  end
end
