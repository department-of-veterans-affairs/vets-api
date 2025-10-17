# frozen_string_literal: true

module UnifiedHealthData
  class Logging
    def initialize(user)
      @user = user
    end

    # Logs the distribution of test codes and names found in the records for analytics purposes
    # This helps identify which test codes are common and might be worth filtering in
    def log_test_code_distribution(records)
      test_code_counts, test_name_counts = count_test_codes_and_names(records)

      return if test_code_counts.empty? && test_name_counts.empty?

      log_distribution_info(test_code_counts, test_name_counts, records.size)
    end

    # Logs the distribution of loinc codes found in the Notes records for analytics purposes
    # This helps identify which loinc codes are being used to identify note types
    def log_loinc_code_distribution(records, record_type = 'Clinical Notes')
      loinc_code_counts = Hash.new(0)

      records.each do |record|
        loinc_codes = record.loinc_codes
        loinc_codes.each { |code| loinc_code_counts[code] += 1 if code.present? }
      end

      return if loinc_code_counts.empty?

      sorted_code_counts = loinc_code_counts.sort_by { |_, count| -count }
      code_count_pairs = sorted_code_counts.map { |code, count| "#{code}:#{count}" }

      Rails.logger.info(
        {
          message: "#{record_type} LOINC code distribution",
          loinc_code_distribution: code_count_pairs.join(','),
          total_codes: sorted_code_counts.size,
          total_records: records.size,
          service: 'unified_health_data'
        }
      )
    end

    private

    def count_test_codes_and_names(records)
      test_code_counts = Hash.new(0)
      test_name_counts = Hash.new(0)

      records.each do |record|
        test_code = record.test_code
        test_name = record.display

        test_code_counts[test_code] += 1 if test_code.present?
        test_name_counts[test_name] += 1 if test_name.present?

        # Log to PersonalInformationLog when test name is 3 characters or less instead of human-friendly name
        log_short_test_name_issue(record) if test_name.present? && test_name.length <= 3
      end

      [test_code_counts, test_name_counts]
    end

    def log_distribution_info(test_code_counts, test_name_counts, total_records)
      sorted_code_counts = test_code_counts.sort_by { |_, count| -count }
      sorted_name_counts = test_name_counts.sort_by { |_, count| -count }

      code_count_pairs = sorted_code_counts.map { |code, count| "#{code}:#{count}" }
      name_count_pairs = sorted_name_counts.map { |name, count| "#{name}:#{count}" }

      Rails.logger.info(
        {
          message: 'UHD test code and name distribution',
          test_code_distribution: code_count_pairs.join(','),
          test_name_distribution: name_count_pairs.join(','),
          total_codes: sorted_code_counts.size,
          total_names: sorted_name_counts.size,
          total_records:,
          service: 'unified_health_data'
        }
      )
    end

    # Logs cases where test name is 3 characters or less instead of a human-friendly name to PersonalInformationLog
    # for secure tracking of patient records with this issue
    def log_short_test_name_issue(record)
      data = {
        icn: @user.icn,
        test_code: record.test_code,
        test_name: record.display,
        record_id: record.id,
        resource_type: record.type,
        date_completed: record.date_completed,
        service: 'unified_health_data'
      }

      PersonalInformationLog.create!(
        error_class: 'UHD Short Test Name Issue',
        data:
      )
    rescue => e
      # Log any errors in creating the PersonalInformationLog without exposing PII
      Rails.logger.error(
        "Error creating PersonalInformationLog for short test name issue: #{e.class.name}",
        { service: 'unified_health_data', backtrace: e.backtrace.first(5) }
      )
    end
  end
end
