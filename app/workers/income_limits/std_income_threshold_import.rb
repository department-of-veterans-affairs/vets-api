# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

require 'net/http'
require 'csv'

module IncomeLimits
  class StdIncomeThresholdImport
    include Sidekiq::Worker

    def fetch_csv_data
      csv_url = 'https://sitewide-public-websites-income-limits-data.s3-us-gov-west-1.amazonaws.com/std_incomethreshold.csv'
      uri = URI(csv_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      response.body if response.code == '200'
    end

    def perform
      ActiveRecord::Base.transaction do
        data = fetch_csv_data
        if data
          CSV.parse(data, headers: true) do |row|
            created = DateTime.strptime(row['CREATED'], '%m/%d/%Y %l:%M:%S.%N %p').to_s
            updated = DateTime.strptime(row['UPDATED'], '%m/%d/%Y %l:%M:%S.%N %p').to_s if row['UPDATED']
            std_income_threshold = StdIncomeThreshold.find_or_initialize_by(id: row['ID'].to_i)
            next unless std_income_threshold.new_record?

            std_income_threshold.assign_attributes(
              income_threshold_year: row['INCOME_THRESHOLD_YEAR'].to_i,
              exempt_amount: row['EXEMPT_AMOUNT'].to_i,
              medical_expense_deductible: row['MEDICAL_EXPENSE_DEDUCTIBLE'].to_i,
              child_income_exclusion: row['CHILD_INCOME_EXCLUSION'].to_i,
              dependent: row['DEPENDENT'].to_i,
              add_dependent_threshold: row['ADD_DEPENDENT_THRESHOLD'].to_i,
              property_threshold: row['PROPERTY_THRESHOLD'].to_i,
              pension_threshold: row['PENSION_THRESHOLD']&.to_i,
              pension_1_dependent: row['PENSION_1_DEPENDENT']&.to_i,
              add_dependent_pension: row['ADD_DEPENDENT_PENSION']&.to_i,
              ninety_day_hospital_copay: row['NINETY_DAY_HOSPITAL_COPAY']&.to_i,
              add_ninety_day_hospital_copay: row['ADD_90_DAY_HOSPITAL_COPAY']&.to_i,
              outpatient_basic_care_copay: row['OUTPATIENT_BASIC_CARE_COPAY']&.to_i,
              outpatient_specialty_copay: row['OUTPATIENT_SPECIALTY_COPAY']&.to_i,
              threshold_effective_date: row['THRESHOLD_EFFECTIVE_DATE'],
              aid_and_attendance_threshold: row['AID_AND_ATTENDANCE_THRESHOLD']&.to_i,
              outpatient_preventive_copay: row['OUTPATIENT_PREVENTIVE_COPAY']&.to_i,
              medication_copay: row['MEDICATION_COPAY']&.to_i,
              medication_copay_annual_cap: row['MEDICATIN_COPAY_ANNUAL_CAP']&.to_i,
              ltc_inpatient_copay: row['LTC_INPATIENT_COPAY']&.to_i,
              ltc_outpatient_copay: row['LTC_OUTPATIENT_COPAY']&.to_i,
              ltc_domiciliary_copay: row['LTC_DOMICILIARY_COPAY']&.to_i,
              inpatient_per_diem: row['INPATIENT_PER_DIEM']&.to_i,
              description: row['DESCRIPTION'],
              version: row['VERSION'].to_i,
              created:,
              updated:,
              created_by: row['CREATED_BY'],
              updated_by: row['UPDATED_BY']
            )

            std_income_threshold.save!
          end
        else
          raise "Failed to fetch CSV data. Response code: #{response.code}"
        end
      end
    rescue => e
      ActiveRecord::Base.rollback_transaction
      raise "error: #{e}"
    end
  end
end
# rubocop:enable Metrics/MethodLength
