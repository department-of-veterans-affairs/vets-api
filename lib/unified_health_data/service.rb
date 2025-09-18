# frozen_string_literal: true

# FIXME: remove after re-factoring class

require 'common/client/base'
require 'common/exceptions/not_implemented'
require_relative 'configuration'
require_relative 'models/prescription_attributes'
require_relative 'models/prescription'
require_relative 'adapters/clinical_notes_adapter'
require_relative 'adapters/prescriptions_adapter'
require_relative 'adapters/conditions_adapter'
require_relative 'adapters/lab_or_test_adapter'
require_relative 'reference_range_formatter'
require_relative 'logging'
require_relative 'client'

module UnifiedHealthData
  class Service
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    # configuration UnifiedHealthData::Configuration

    def initialize(user)
      super()
      @user = user
    end

    def get_labs(start_date:, end_date:)
      with_monitoring do
        response = uhd_client.get_labs_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        parsed_records = lab_or_test_adapter.parse_labs(combined_records)
        filtered_records = filter_records(parsed_records)

        # Log test code distribution after filtering is applied
        logger.log_test_code_distribution(parsed_records)

        filtered_records
      end
    end

    def get_conditions
      with_monitoring do
        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        response = uhd_client.get_conditions_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        conditions_adapter.parse(combined_records)
      end
    end

    def get_single_condition(condition_id)
      with_monitoring do
        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        response = uhd_client.get_conditions_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        target_record = combined_records.find { |record| record['resource']['id'] == condition_id }
        return nil unless target_record

        conditions_adapter.parse([target_record]).first
      end
    end

    def get_prescriptions
      with_monitoring do
        response = uhd_client.get_all_prescriptions(@user.icn)
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

    def refill_prescription(orders)
      with_monitoring do
        response = uhd_client.refill_prescription(build_refill_request_body(orders))
        parse_refill_response(response)
      end
    rescue => e
      Rails.logger.error("Error submitting prescription refill: #{e.message}")
      build_error_response(orders)
    end

    def get_care_summaries_and_notes
      with_monitoring do
        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        response = uhd_client.get_notes_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = parse_response_body(response.body)

        remap_vista_uid(body)
        combined_records = fetch_combined_records(body)
        filtered = combined_records.select { |record| record['resource']['resourceType'] == 'DocumentReference' }

        parsed_notes = parse_notes(filtered)

        log_loinc_codes_enabled? && logger.log_loinc_code_distribution(parsed_notes)

        parsed_notes
      end
    end

    def get_single_summary_or_note(note_id)
      with_monitoring do
        # TODO: we will replace this with a direct call to the API once available
        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        response = uhd_client.get_notes_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = parse_response_body(response.body)

        remap_vista_uid(body)
        combined_records = fetch_combined_records(body)
        filtered = combined_records.find { |record| record['resource']['id'] == note_id }
        return nil unless filtered

        parse_single_note(filtered)
      end
    end

    private

    # Shared
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

    # Labs and Tests methods
    def filter_records(records)
      return all_records_response(records) unless filtering_enabled?

      apply_test_code_filtering(records)
    end

    def filtering_enabled?
      Flipper.enabled?(:mhv_accelerated_delivery_uhd_filtering_enabled, @user)
    end

    def all_records_response(records)
      Rails.logger.info(
        message: 'UHD filtering disabled - returning all records',
        total_records: records.size,
        service: 'unified_health_data'
      )
      records
    end

    def apply_test_code_filtering(records)
      filtered = records.select { |record| test_code_enabled?(record.test_code) }

      Rails.logger.info(
        message: 'UHD filtering enabled - applied test code filtering',
        total_records: records.size,
        filtered_records: filtered.size,
        service: 'unified_health_data'
      )

      filtered
    end

    def test_code_enabled?(test_code)
      case test_code
      when 'CH'
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_ch_enabled, @user)
      when 'SP'
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_sp_enabled, @user)
      when 'MB'
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_mb_enabled, @user)
      else
        false # Reject any other test codes for now, but we'll log them for analysis
      end
    end

    # Prescription refill helper methods
    def build_refill_request_body(orders)
      {
        patientId: @user.icn,
        orders: orders.map do |order|
          {
            orderId: order[:id].to_s,
            stationNumber: order[:stationNumber].to_s
          }
        end
      }
    end

    def build_error_response(orders)
      {
        success: [],
        failed: orders.map do |order|
          { id: order[:id], error: 'Service unavailable', station_number: order[:stationNumber] }
        end
      }
    end

    def parse_refill_response(response)
      body = parse_response_body(response.body)

      # Ensure we have an array response format
      refill_items = body.is_a?(Array) ? body : []

      # Parse successful refills
      successes = extract_successful_refills(refill_items)

      # Parse failed refills
      failures = extract_failed_refills(refill_items)

      {
        success: successes,
        failed: failures
      }
    end

    def extract_successful_refills(refill_items)
      # Parse successful refills from API response array
      successful_refills = refill_items.select { |item| item['success'] == true }
      successful_refills.map do |refill|
        {
          id: refill['orderId'],
          status: refill['message'] || 'submitted',
          station_number: refill['stationNumber']
        }
      end
    end

    def extract_failed_refills(refill_items)
      # Parse failed refills from API response array
      failed_refills = refill_items.select { |item| item['success'] == false }
      failed_refills.map do |failure|
        {
          id: failure['orderId'],
          error: failure['message'] || 'Unable to process refill',
          station_number: failure['stationNumber']
        }
      end
    end

    # Care Summaries and Notes methods
    def remap_vista_uid(records)
      records['vista']['entry']&.each do |note|
        vista_uid_identifier = note['resource']['identifier'].find { |id| id['system'] == 'vista-uid' }
        next unless vista_uid_identifier && vista_uid_identifier['value']

        new_id_array = vista_uid_identifier['value'].split(':')
        note['resource']['id'] = new_id_array[-3..].join('-')
      end
    end

    # Care Summaries and Notes methods
    def parse_notes(records)
      return [] if records.blank?

      parsed = records.map { |record| parse_single_note(record) }
      parsed.compact
    end

    def parse_single_note(record)
      return nil if record.blank?

      clinical_notes_adapter.parse(record)
    end

    def log_loinc_codes_enabled?
      Flipper.enabled?(:mhv_accelerated_delivery_uhd_loinc_logging_enabled, @user)
    end

    # Instantiate client, adapters, etc. once per service instance

    def uhd_client
      @uhd_client ||= UnifiedHealthData::Client.new
    end

    def lab_or_test_adapter
      @lab_or_test_adapter ||= UnifiedHealthData::Adapters::LabOrTestAdapter.new
    end

    def clinical_notes_adapter
      @clinical_notes_adapter ||= UnifiedHealthData::Adapters::ClinicalNotesAdapter.new
    end

    def conditions_adapter
      @conditions_adapter ||= UnifiedHealthData::Adapters::ConditionsAdapter.new
    end

    def logger
      @logger ||= UnifiedHealthData::Logging.new(@user)
    end
  end
end # rubocop:enable Metrics/ClassLength
