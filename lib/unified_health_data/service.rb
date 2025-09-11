# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/not_implemented'
require_relative 'configuration'
require_relative 'models/lab_or_test'
require_relative 'models/clinical_notes'
require_relative 'models/prescription_attributes'
require_relative 'models/prescription'
require_relative 'adapters/clinical_notes_adapter'
require_relative 'adapters/prescriptions_adapter'
require_relative 'reference_range_formatter'
require_relative 'lab_data_processor'

module UnifiedHealthData
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::Configuration

    def initialize(user)
      super()
      @user = user
    end

    def get_labs(start_date:, end_date:)
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn
        path = "#{config.base_path}labs?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        processor = UnifiedHealthData::LabDataProcessor.new(@user)
        parsed_records = processor.parse_labs(combined_records)
        filtered_records = processor.process_labs(parsed_records)

        # Log test code distribution after filtering is applied
        log_test_code_distribution(parsed_records)

        filtered_records
      end
    end

    def get_care_summaries_and_notes
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn

        # NOTE: we must pass in a startDate and endDate to SCDF
        # Start date defaults to 120 years? (TODO: what are the legal requirements for oldest records to display?)
        start_date = '1900-01-01'
        # End date defaults to today
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)

        filtered = combined_records.select { |record| record['resource']['resourceType'] == 'DocumentReference' }

        parse_notes(filtered)
      end
    end

    def get_prescriptions(start_date:, end_date:)
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn
        path = "#{config.base_path}medications?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"

        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        adapter = UnifiedHealthData::Adapters::PrescriptionsAdapter.new
        prescriptions = adapter.parse(body)

        Rails.logger.info(
          message: 'UHD prescriptions retrieved',
          total_prescriptions: prescriptions.size,
          service: 'unified_health_data'
        )

        prescriptions
      end
    end

    def refill_prescription(prescription_ids)
      with_monitoring do
        headers = {
          'Authorization' => fetch_access_token,
          'x-api-key' => config.x_api_key,
          'Content-Type' => 'application/json'
        }

        path = "#{config.base_path}prescriptions/refill"

        # Format the request body
        request_body = {
          prescriptions: prescription_ids.map { |id| { orderId: id.to_s } }
        }

        response = perform(:post, path, request_body.to_json, headers)
        parse_refill_response(response)
      end
    rescue => e
      Rails.logger.error("Error submitting prescription refill: #{e.message}")
      {
        success: [],
        failed: prescription_ids.map { |id| { id:, error: 'Service unavailable' } }
      }
    end

    def get_single_summary_or_note(note_id)
      # TODO: refactor out common bits into a client type method - most of this is repeated from above
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn

        # NOTE: we must pass in a startDate and endDate to SCDF
        # Start date defaults to 120 years? (TODO: what are the legal requirements for oldest records to display?)
        start_date = '1900-01-01'
        # End date defaults to today
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)

        filtered = combined_records.select { |record| record['resource']['id'] == note_id }

        parse_single_note(filtered[0])
      end
    end

    private

    # Shared
    def fetch_access_token
      with_monitoring do
        response = connection.post(config.token_path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = {
            appId: config.app_id,
            appToken: config.app_token,
            subject: config.subject,
            userType: config.user_type
          }.to_json
        end
        response.headers['authorization']
      end
    end

    def parse_response_body(body)
      # FIXME: workaround for testing
      body.is_a?(String) ? JSON.parse(body) : body
    end

    def fetch_combined_records(body)
      return [] if body.nil?

      vista_records = body.dig('vista', 'entry') || []
      oracle_health_records = body.dig('oracle-health', 'entry') || []
      vista_records + oracle_health_records
    end

    # Logs the distribution of test codes and names found in the records for analytics purposes
    # This helps identify which test codes are common and might be worth filtering in
    def log_test_code_distribution(records)
      test_code_counts, test_name_counts = count_test_codes_and_names(records)

      return if test_code_counts.empty? && test_name_counts.empty?

      log_distribution_info(test_code_counts, test_name_counts, records.size)
    end

    def count_test_codes_and_names(records)
      test_code_counts = Hash.new(0)
      test_name_counts = Hash.new(0)

      records.each do |record|
        test_code = record.attributes.test_code
        test_name = record.attributes.display

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
        test_code: record.attributes.test_code,
        test_name: record.attributes.display,
        record_id: record.id,
        resource_type: record.type,
        date_completed: record.attributes.date_completed,
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

    # Care Summaries and Notes methods
    def parse_notes(records)
      return [] if records.blank?

      # Parse using the adapter
      parsed = records.map { |record| clinical_notes_adapter.parse(record) }
      parsed.compact
    end

    # Prescription refill helper methods
    def parse_refill_response(response)
      body = parse_response_body(response.body)

      # Parse successful refills
      successes = extract_successful_refills(body)

      # Parse failed refills
      failures = extract_failed_refills(body)

      {
        success: successes,
        failed: failures
      }
    end

    def extract_successful_refills(body)
      # Parse successful refills from API response
      successful_refills = body['successfulRefills'] || []
      successful_refills.map do |refill|
        {
          id: refill['prescriptionId'],
          status: refill['status'] || 'submitted'
        }
      end
    end

    def extract_failed_refills(body)
      # Assuming the API returns detailed error info for failures
      # Adjust based on actual API response format
      failed_refills = body['failedRefills'] || []
      failed_refills.map do |failure|
        {
          id: failure['prescriptionId'],
          error: failure['reason'] || 'Unable to process refill'
        }
      end
    end

    def parse_single_note(record)
      return nil if record.blank?

      # Parse using the adapter
      clinical_notes_adapter.parse(record)
    end

    def clinical_notes_adapter
      @clinical_notes_adapter ||= UnifiedHealthData::V2::Adapters::ClinicalNotesAdapter.new
    end
  end
end
