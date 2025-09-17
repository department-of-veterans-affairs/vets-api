# frozen_string_literal: true

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
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn

        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}conditions?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        conditions_adapter.parse(combined_records)
      end
    end

    def get_care_summaries_and_notes
      with_monitoring do
        patient_id = @user.icn

        # NOTE: we must pass in a startDate and endDate to SCDF
        # Start date defaults to 120 years? (TODO: what are the legal requirements for oldest records to display?)
        start_date = '1900-01-01'
        # End date defaults to today
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, request_headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)

        filtered = combined_records.select { |record| record['resource']['resourceType'] == 'DocumentReference' }

        parse_notes(filtered)
      end
    end

    def get_prescriptions
      with_monitoring do
        patient_id = @user.icn
        path = "#{config.base_path}medications?patientId=#{patient_id}"

        response = perform(:get, path, nil, request_headers)
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
        path = "#{config.base_path}medications/rx/refill"
        request_body = build_refill_request_body(orders)
        response = perform(:post, path, request_body.to_json, request_headers(include_content_type: true))
        parse_refill_response(response)
      end
    rescue => e
      Rails.logger.error("Error submitting prescription refill: #{e.message}")
      build_error_response(orders)
    end

    def get_single_summary_or_note(note_id)
      # TODO: refactor out common bits into a client type method - most of this is repeated from above
      with_monitoring do
        patient_id = @user.icn

        # NOTE: we must pass in a startDate and endDate to SCDF
        # Start date defaults to 120 years? (TODO: what are the legal requirements for oldest records to display?)
        start_date = '1900-01-01'
        # End date defaults to today
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, request_headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)

        filtered = combined_records.select { |record| record['resource']['id'] == note_id }

        parse_single_note(filtered[0])
      end
    end

    private

    # Shared
    # def fetch_access_token
    #   with_monitoring do
    #     response = connection.post(config.token_path) do |req|
    #       req.headers['Content-Type'] = 'application/json'
    #       req.body = {
    #         appId: config.app_id,
    #         appToken: config.app_token,
    #         subject: config.subject,
    #         userType: config.user_type
    #       }.to_json
    #     end
    #     response.headers['authorization']
    #   end
    # end

    # def request_headers(include_content_type: false)
    #   headers = {
    #     'Authorization' => fetch_access_token,
    #     'x-api-key' => config.x_api_key
    #   }
    #   headers['Content-Type'] = 'application/json' if include_content_type
    #   headers
    # end

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
    def parse_notes(records)
      return [] if records.blank?

      parsed = records.map { |record| parse_single_note(record) }
      parsed.compact
    end

    def parse_single_note(record)
      return nil if record.blank?

      clinical_notes_adapter.parse(record)
    end

    # Instantiate adapters, etc. once per service instance

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
end
