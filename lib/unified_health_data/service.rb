# frozen_string_literal: true

# FIXME: remove after re-factoring class

require 'common/client/base'
require 'common/exceptions/not_implemented'
require_relative 'configuration'
require_relative 'models/lab_or_test'
require_relative 'models/clinical_notes'
require_relative 'models/condition'
require_relative 'models/prescription'
require_relative 'adapters/clinical_notes_adapter'
require_relative 'adapters/prescriptions_adapter'
require_relative 'reference_range_formatter'
require_relative 'adapters/conditions_adapter'
require_relative 'logging'

module UnifiedHealthData
  class Service < Common::Client::Base # rubocop:disable Metrics/ClassLength
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::Configuration

    def initialize(user)
      super()
      @user = user
    end

    def get_labs(start_date:, end_date:)
      with_monitoring do
        headers = request_headers
        patient_id = @user.icn
        path = "#{config.base_path}labs?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        parsed_records = parse_labs(combined_records)
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

    def get_single_condition(condition_id)
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn

        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}conditions?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

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
        patient_id = @user.icn
        path = "#{config.base_path}medications?patientId=#{patient_id}"

        response = perform(:get, path, nil, request_headers)
        body = parse_response_body(response.body)

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
      with_monitoring do
        path = "#{config.base_path}medications/rx/refill"
        request_body = build_refill_request_body(orders)
        response = perform(:post, path, request_body.to_json, request_headers(include_content_type: true))
        parse_refill_response(response)
      end
    rescue Common::Exceptions::BackendServiceException => e
      raise e if e.original_status && e.original_status >= 500
    rescue => e
      Rails.logger.error("Error submitting prescription refill: #{e.message}")
      build_error_response(orders)
    end

    def get_care_summaries_and_notes
      with_monitoring do
        patient_id = @user.icn

        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, request_headers)
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
      # TODO: refactor out common bits into a client type method - most of this is repeated from above
      with_monitoring do
        patient_id = @user.icn

        # NOTE: we must pass in a startDate and endDate to SCDF
        start_date = '1900-01-01'
        end_date = Time.zone.today.to_s

        path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, request_headers)
        body = parse_response_body(response.body)

        remap_vista_uid(body)
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

    def request_headers(include_content_type: false)
      headers = {
        'Authorization' => fetch_access_token,
        'x-api-key' => config.x_api_key
      }
      headers['Content-Type'] = 'application/json' if include_content_type
      headers
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
      filtered = records.select { |record| test_code_enabled?(record.attributes.test_code) }

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

    def parse_labs(records)
      return [] if records.blank?

      filtered = records.select do |record|
        record['resource'] && record['resource']['resourceType'] == 'DiagnosticReport'
      end
      parsed = filtered.map { |record| parse_single_record(record) }
      parsed.compact
    end

    def parse_single_record(record)
      return nil if record.nil? || record['resource'].nil?

      code = fetch_code(record)
      encoded_data = record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : ''
      observations = fetch_observations(record)
      return nil unless code && (encoded_data || observations)

      attributes = build_lab_or_test_attributes(record)

      UnifiedHealthData::LabOrTest.new(
        id: record['resource']['id'],
        type: record['resource']['resourceType'],
        attributes:
      )
    end

    def build_lab_or_test_attributes(record)
      location = fetch_location(record)
      code = fetch_code(record)
      encoded_data = record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : ''
      contained = record['resource']['contained']
      sample_tested = fetch_sample_tested(record['resource'], contained)
      body_site = fetch_body_site(record['resource'], contained)
      observations = fetch_observations(record)
      ordered_by = fetch_ordered_by(record)

      UnifiedHealthData::Attributes.new(
        display: fetch_display(record),
        test_code: code,
        date_completed: record['resource']['effectiveDateTime'],
        sample_tested:,
        encoded_data:,
        location:,
        ordered_by:,
        observations:,
        body_site:
      )
    end

    def fetch_location(record)
      if record['resource']['contained'].nil?
        nil
      else
        location_object = record['resource']['contained'].find { |resource| resource['resourceType'] == 'Organization' }
        location_object.nil? ? nil : location_object['name']
      end
    end

    def fetch_code(record)
      return nil if record['resource']['category'].blank?

      coding = record['resource']['category'].find do |category|
        category['coding'].present? && category['coding'][0]['code'] != 'LAB'
      end
      coding ? coding['coding'][0]['code'] : nil
    end

    def fetch_body_site(resource, contained)
      body_sites = []

      return '' unless resource['basedOn']
      return '' if contained.nil?

      service_request_references = resource['basedOn'].pluck('reference')
      service_request_references.each do |reference|
        service_request_object = contained.find do |contained_resource|
          contained_resource['resourceType'] == 'ServiceRequest' &&
            contained_resource['id'] == extract_reference_id(reference)
        end

        next unless service_request_object && service_request_object['bodySite']

        service_request_object['bodySite'].each do |body_site|
          next unless body_site['coding'].is_a?(Array)

          body_site['coding'].each do |coding|
            body_sites << coding['display'] if coding['display']
          end
        end
      end

      body_sites.join(', ').strip
    end

    def fetch_sample_tested(record, contained)
      return '' unless record['specimen']
      return '' if contained.nil?

      specimen_references = if record['specimen'].is_a?(Hash)
                              [extract_reference_id(record['specimen']['reference'])]
                            elsif record['specimen'].is_a?(Array)
                              record['specimen'].map { |specimen| extract_reference_id(specimen['reference']) }
                            end

      specimens =
        specimen_references.map do |reference|
          specimen_object = contained.find do |resource|
            resource['resourceType'] == 'Specimen' && resource['id'] == reference
          end
          specimen_object['type']['text'] if specimen_object
        end

      specimens.compact.join(', ').strip
    end

    def fetch_observations(record)
      return [] if record['resource']['contained'].nil?

      record['resource']['contained'].select { |resource| resource['resourceType'] == 'Observation' }.map do |obs|
        sample_tested = fetch_sample_tested(obs, record['resource']['contained'])
        body_site = fetch_body_site(obs, record['resource']['contained'])
        UnifiedHealthData::Observation.new(
          test_code: obs['code']['text'],
          value: fetch_observation_value(obs),
          reference_range: UnifiedHealthData::ReferenceRangeFormatter.format(obs),
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || '',
          sample_tested:,
          body_site:
        )
      end
    end

    def fetch_observation_value(obs)
      type, text = if obs['valueQuantity']
                     ['quantity', format_quantity_value(obs['valueQuantity'])]
                   elsif obs['valueCodeableConcept']
                     ['codeable-concept', obs['valueCodeableConcept']['text']]
                   elsif obs['valueString']
                     ['string', obs['valueString']]
                   elsif obs['valueDateTime']
                     ['date-time', obs['valueDateTime']]
                   elsif obs['valueAttachment']
                     Rails.logger.error(
                       message: "Observation with ID #{obs['id']} has unsupported value type: Attachment"
                     )
                     raise Common::Exceptions::NotImplemented
                   else
                     [nil, nil]
                   end
      { text:, type: }
    end

    def format_quantity_value(value_quantity)
      value = value_quantity['value']
      unit = value_quantity['unit']
      comparator = value_quantity['comparator']

      result_text = ''
      result_text += comparator.to_s if comparator.present?
      result_text += value.to_s
      result_text += " #{unit}" if unit.present?

      result_text
    end

    def fetch_ordered_by(record)
      if record['resource']['contained']
        practitioner_object = record['resource']['contained'].find do |resource|
          resource['resourceType'] == 'Practitioner'
        end
        if practitioner_object
          name = practitioner_object['name'].first
          "#{name['given'].join(' ')} #{name['family']}"
        end
      end
    end

    def extract_reference_id(reference)
      reference.split('/').last
    end

    def fetch_display(record)
      contained = record['resource']['contained']
      if contained&.any? { |r| r['resourceType'] == 'ServiceRequest' && r['code']&.dig('text').present? }
        service_request = contained.find do |r|
          r['resourceType'] == 'ServiceRequest' && r['code']&.dig('text').present?
        end
        service_request['code']['text']
      else
        record['resource']['code'] ? record['resource']['code']['text'] : ''
      end
    end

    # Conditions methods
    def conditions_adapter
      @conditions_adapter ||= UnifiedHealthData::Adapters::ConditionsAdapter.new
    end

    # Prescription refill helper methods
    def build_refill_request_body(orders)
      {
        patientId: @user.icn,
        orders: orders.map do |order|
          {
            orderId: order['id'].to_s,
            stationNumber: order['stationNumber'].to_s
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

      # Parse using the adapter
      clinical_notes_adapter.parse(record)
    end

    def log_loinc_codes_enabled?
      Flipper.enabled?(:mhv_accelerated_delivery_uhd_loinc_logging_enabled, @user)
    end

    def clinical_notes_adapter
      @clinical_notes_adapter ||= UnifiedHealthData::V2::Adapters::ClinicalNotesAdapter.new
    end

    def logger
      @logger ||= UnifiedHealthData::Logging.new(@user)
    end
  end
end # rubocop:enable Metrics/ClassLength
