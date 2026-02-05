# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/not_implemented'
require_relative 'configuration'
require_relative 'models/prescription'
require_relative 'adapters/allergy_adapter'
require_relative 'adapters/clinical_notes_adapter'
require_relative 'adapters/immunization_adapter'
require_relative 'adapters/prescriptions_adapter'
require_relative 'adapters/conditions_adapter'
require_relative 'adapters/lab_or_test_adapter'
require_relative 'adapters/vital_adapter'
require_relative 'reference_range_formatter'
require_relative 'logging'
require_relative 'client'

module UnifiedHealthData
  class Service
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    def initialize(user)
      super()
      @user = user
    end

    def get_labs(start_date:, end_date:)
      with_monitoring do
        response = uhd_client.get_labs_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        combined_records = fetch_combined_records(body)
        parsed_records = lab_or_test_adapter.parse_labs(combined_records)

        # Log test code distribution
        logger.log_test_code_distribution(parsed_records)

        parsed_records
      end
    end

    def get_conditions
      with_monitoring do
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_conditions_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        combined_records = fetch_combined_records(body)
        conditions_adapter.parse(combined_records)
      end
    end

    def get_single_condition(condition_id)
      with_monitoring do
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_conditions_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        combined_records = fetch_combined_records(body)
        target_record = combined_records.find { |record| record['resource']['id'] == condition_id }
        return nil unless target_record

        conditions_adapter.parse([target_record]).first
      end
    end

    # Retrieves prescriptions for the current user from unified health data sources
    #
    # @param current_only [Boolean] When true, applies filtering logic to exclude:
    #   - Discontinued/expired medications older than 180 days
    #   Defaults to false to return all prescriptions without filtering
    # @return [Array<UnifiedHealthData::Prescription>] Array of prescription objects
    def get_prescriptions(current_only: false)
      with_monitoring do
        start_date = default_start_date
        end_date = default_end_date
        response = uhd_client.get_prescriptions_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        adapter = UnifiedHealthData::Adapters::PrescriptionsAdapter.new(@user)
        prescriptions = adapter.parse(body, current_only:)

        Rails.logger.info(
          message: 'UHD prescriptions retrieved',
          total_prescriptions: prescriptions.size,
          current_filtering_applied: current_only,
          service: 'unified_health_data'
        )

        prescriptions
      end
    end

    def refill_prescription(orders)
      normalized_orders = normalize_orders(orders)
      with_monitoring do
        response = uhd_client.refill_prescription_orders(build_refill_request_body(normalized_orders))
        result = parse_refill_response(response)
        validate_refill_response_count(normalized_orders, result)
        increment_refill(result[:success].size) if result[:success].present?
        result
      end
    rescue Common::Exceptions::BackendServiceException => e
      raise e if e.original_status && e.original_status >= 500
    rescue => e
      Rails.logger.error("Error submitting prescription refill: #{e.message}")
      build_error_response(normalized_orders)
    end

    def get_care_summaries_and_notes(start_date: nil, end_date: nil)
      with_monitoring do
        # Treat blank as "use default" so filtering still runs with a valid range
        start_date = nil if start_date.blank?
        end_date = nil if end_date.blank?
        # Validate user-provided dates BEFORE applying defaults
        validate_date_param(start_date, 'start_date') if start_date
        validate_date_param(end_date, 'end_date') if end_date

        # Apply defaults after validation
        start_date ||= default_start_date
        end_date ||= default_end_date

        response = uhd_client.get_notes_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        remap_vista_uid(body)
        combined_records = fetch_combined_records(body)
        doc_ref_records = combined_records.select { |record| record['resource']['resourceType'] == 'DocumentReference' }
        parsed_notes = parse_notes(doc_ref_records)

        # Filter by date range on parsed notes (single source of truth for what we return).
        # SCDF may return notes outside the requested range; this ensures only in-range notes are returned.
        parsed_notes = filter_parsed_notes_by_date_range(parsed_notes, start_date, end_date)

        log_loinc_codes_enabled? && logger.log_loinc_code_distribution(parsed_notes, 'Clinical Notes')

        parsed_notes
      end
    end

    def get_single_summary_or_note(note_id)
      with_monitoring do
        # TODO: we will replace this with a direct call to the API once available
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_notes_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        remap_vista_uid(body)
        combined_records = fetch_combined_records(body)
        filtered = combined_records.find { |record| record['resource']['id'] == note_id }
        return nil unless filtered

        parse_single_note(filtered)
      end
    end

    def get_vitals
      with_monitoring do
        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_vitals_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        combined_records = fetch_combined_records(body)

        vitals_adapter.parse(combined_records)
      end
    end

    def get_allergies
      with_monitoring do
        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_allergies_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        remap_vista_identifier(body)
        combined_records = fetch_combined_records(body)

        allergy_adapter.parse(combined_records)
      end
    end

    def get_single_allergy(allergy_id)
      with_monitoring do
        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_allergies_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        remap_vista_identifier(body)
        combined_records = fetch_combined_records(body)

        filtered = combined_records.find { |record| record['resource']['id'] == allergy_id }
        return nil unless filtered

        allergy_adapter.parse_single_allergy(filtered)
      end
    end

    def get_immunizations
      with_monitoring do
        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_immunizations_by_date(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        combined_records = fetch_combined_records(body)

        immunization_adapter.parse(combined_records)
      end
    end

    # Retrieves the After Visit Summary for the given appointment ID from unified health data sources
    #
    # @param appt_id [String] The ID of the appointment to retrieve the summary for
    # NOTE: This is not the ID used by the VAOS service, but from the appointment object's `identifier` field:
    # `"identifier": [{"system": "urn:va.gov:masv2:cerner:appointment", "value": "Appointment/1234567"}]`
    #
    # @param include_binary [Boolean] Whether to include binary data in the response
    #
    # @return [Array<UnifiedHealthData::AfterVisitSummary>] Array of AVS objects
    # Because an appointment can have multiple documents associated with it
    # (e.g., AVS, discharge instructions, etc.), we return an array here
    def get_appt_avs(appt_id:, include_binary: false)
      with_monitoring do
        response = uhd_client.get_avs(patient_id: @user.icn, appt_id:)
        body = response.body

        summaries = body['entry'].select { |record| record['resource']['resourceType'] == 'DocumentReference' }
        parsed_avs_meta = summaries.map do |summary|
          clinical_notes_adapter.parse_avs_with_metadata(summary, appt_id, include_binary)
        end
        log_loinc_codes_enabled? && logger.log_loinc_code_distribution(parsed_avs_meta, 'AVS')
        parsed_avs_meta.compact
      end
    end

    def get_avs_binary_data(doc_id:, appt_id:)
      with_monitoring do
        response = uhd_client.get_avs(patient_id: @user.icn, appt_id:)
        body = response.body

        summary = body['entry'].find do |record|
          record['resource']['resourceType'] == 'DocumentReference' && record['resource']['id'] == doc_id
        end
        clinical_notes_adapter.parse_avs_binary(summary)
      end
    end

    # Retrieves CCD binary data for download
    # @param format [String] Format to retrieve: 'xml', 'html', or 'pdf'
    # @return [UnifiedHealthData::BinaryData, nil] Binary data object with Base64 encoded content, or nil if not found
    # @raise [ArgumentError] if the format is invalid or not available
    def get_ccd_binary(format: 'xml')
      with_monitoring do
        start_date = default_start_date
        end_date = default_end_date

        response = uhd_client.get_ccd(patient_id: @user.icn, start_date:, end_date:)
        body = response.body

        document_ref = body['entry']&.find do |entry|
          entry['resource'] && entry['resource']['resourceType'] == 'DocumentReference'
        end
        return nil unless document_ref

        clinical_notes_adapter.parse_ccd_binary(document_ref, format)
      end
    end

    private

    # Shared
    def fetch_combined_records(body)
      return [] if body.nil?

      vista_records = (body.dig('vista', 'entry') || []).map { |r| r.merge('source' => 'vista') }
      oracle_health_records = (body.dig('oracle-health', 'entry') || []).map do |r|
        r.merge('source' => 'oracle-health')
      end
      vista_records + oracle_health_records
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

    def normalize_orders(orders)
      return [] if orders.blank?

      orders.map do |order|
        next order unless order.respond_to?(:with_indifferent_access)

        order.with_indifferent_access
      end
    end

    def parse_refill_response(response)
      body = response.body

      # Ensure we have an array response format
      refill_items = body.is_a?(Array) ? body : []

      # Parse successful refills
      successes = extract_successful_refills(refill_items)

      # Parse failed refills
      failures = extract_failed_refills(refill_items)

      {
        success: successes || [],
        failed: failures || []
      }
    end

    def validate_refill_response_count(normalized_orders, result)
      orders_sent = normalized_orders.size
      orders_received = result[:success].size + result[:failed].size

      return if orders_sent == orders_received

      error_message = "Refill response count mismatch: sent #{orders_sent} orders, " \
                      "received #{orders_received} responses"
      Rails.logger.error(error_message)
      raise Common::Exceptions::PrescriptionRefillResponseMismatch.new(orders_sent, orders_received)
    end

    def extract_successful_refills(refill_items)
      # Parse successful refills from API response array
      successful_refills = refill_items.select { |item| item['success'] == true }
      successful_refills.map do |refill|
        order = refill['order'] || refill
        {
          id: order['orderId'],
          status: refill['message'] || 'submitted',
          station_number: order['stationNumber']
        }
      end
    end

    def extract_failed_refills(refill_items)
      # Parse failed refills from API response array
      failed_refills = refill_items.select { |item| item['success'] == false }
      failed_refills.map do |failure|
        order = failure['order'] || failure
        {
          id: order['orderId'],
          error: failure['message'] || 'Unable to process refill',
          station_number: order['stationNumber']
        }
      end
    end

    # Allergies methods
    def remap_vista_identifier(records)
      # TODO: Placeholder; will transition to a vista_uid
      records['vista']['entry']&.each do |allergy|
        vista_identifier = allergy['resource']['identifier']&.find do |id|
          id['system'].starts_with?('https://va.gov/systems/')
        end
        next unless vista_identifier && vista_identifier['value']

        allergy['resource']['id'] = vista_identifier['value']
      end
    end

    # Care Summaries and Notes methods
    # Keeps only parsed notes whose date falls within [start_date, end_date] (inclusive).
    # Filtering on parsed notes (same objects we return) so the response is guaranteed correct.
    def filter_parsed_notes_by_date_range(notes, start_date, end_date)
      return notes if notes.blank?
      return notes if start_date.blank? || end_date.blank?

      start_d = DateTime.parse(start_date.to_s).to_date
      end_d = DateTime.parse(end_date.to_s).to_date

      notes.select do |note|
        next false if note.blank? || note.date.blank?

        note_date = DateTime.parse(note.date.to_s).to_date
        note_date >= start_d && note_date <= end_d
      rescue ArgumentError, TypeError
        Rails.logger.warn(
          'UnifiedHealthData::Service#filter_parsed_notes_by_date_range ' \
          "excluding note due to invalid date. note_id=#{note&.id.inspect} " \
          "note_date=#{note&.date.inspect}"
        )
        false
      end
    end

    def remap_vista_uid(records)
      records['vista']['entry']&.each do |note|
        vista_uid_identifier = note['resource']['identifier']&.find { |id| id['system'] == 'vista-uid' }
        next unless vista_uid_identifier && vista_uid_identifier['value']

        new_id_array = vista_uid_identifier['value'].split(':')
        note['resource']['id'] = new_id_array[-3..].join('-')
      end
    end

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

    def increment_refill(count = 1)
      StatsD.increment("#{STATSD_KEY_PREFIX}.refills.requested", count)
    end

    # Instantiate client, adapters, etc. once per service instance

    def uhd_client
      @uhd_client ||= UnifiedHealthData::Client.new
    end

    def allergy_adapter
      @allergy_adapter ||= UnifiedHealthData::Adapters::AllergyAdapter.new
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

    def vitals_adapter
      @vitals_adapter ||= UnifiedHealthData::Adapters::VitalAdapter.new
    end

    def immunization_adapter
      @immunization_adapter ||= UnifiedHealthData::Adapters::ImmunizationAdapter.new(@user)
    end

    def logger
      @logger ||= UnifiedHealthData::Logging.new(@user)
    end

    # Date helpers (single source for default UHD date range)
    def default_start_date
      '1900-01-01'
    end

    def default_end_date
      Time.zone.today.to_s
    end

    def validate_date_param(date_string, param_name)
      Date.parse(date_string)
    rescue ArgumentError, TypeError
      raise ArgumentError, "Invalid #{param_name}: '#{date_string}'. Expected format: YYYY-MM-DD"
    end
  end
end
