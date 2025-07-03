# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/not_implemented'
require_relative 'configuration'
require_relative 'models/lab_or_test'

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
        parsed_records = parse_labs(combined_records)
        filtered_records = filter_records(parsed_records)

        # Log test code distribution after filtering is applied
        log_test_code_distribution(parsed_records)

        filtered_records
      end
    end

    private

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

    def filter_records(records)
      records.select do |record|
        case record.attributes.test_code
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
          reference_range: fetch_reference_range(obs),
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || '',
          sample_tested:,
          body_site:
        )
      end
    end

    # Main method to fetch reference range from observation
    def fetch_reference_range(obs)
      return '' unless obs['referenceRange'].is_a?(Array) && !obs['referenceRange'].empty?

      begin
        # Process each range element and transform it to a formatted string
        formatted_ranges = obs['referenceRange'].map do |range|
          next '' unless range.is_a?(Hash)

          # Use the text directly if available, otherwise format it
          if range['text'].is_a?(String) && !range['text'].empty?
            range['text']
          else
            format_reference_range(range)
          end
        end

        # Filter out empty strings and join the results
        formatted_ranges.reject(&:empty?).join(', ').strip
      rescue => e
        Rails.logger.error("Error processing reference range: #{e.message}")
        ''
      end
    end

    # Format a reference range into a string representation
    def format_reference_range(range)
      return '' unless range.is_a?(Hash)

      begin
        return range['text'] if range['text'].is_a?(String) && !range['text'].empty?

        return format_numeric_range(range) if range['low'].is_a?(Hash) || range['high'].is_a?(Hash)

        ''
      rescue => e
        Rails.logger.error("Error processing individual reference range: #{e.message}")
        ''
      end
    end

    # Extract numeric value and unit from range component
    def extract_range_component(component)
      # Handle the case where component is not a hash
      return [nil, ''] unless component.is_a?(Hash)

      value = component&.dig('value')
      value = nil unless value.is_a?(Numeric)
      unit = component&.dig('unit').is_a?(String) ? component&.dig('unit') : ''
      [value, unit]
    end

    # Determine range type prefix
    def get_range_type_prefix(range)
      return '' unless range.is_a?(Hash) && range['type'].present?

      # Handle the case where type is not a hash
      return '' unless range['type'].is_a?(Hash)

      type_text = range['type']['text'].is_a?(String) ? range['type']['text'] : nil

      # Always return the range type prefix if it exists
      if type_text
        "#{type_text}: "
      else
        ''
      end
    end

    # Format a numeric reference range
    def format_numeric_range(range)
      # Extract values safely
      low_value, low_unit = extract_range_component(range['low'])
      high_value, high_unit = extract_range_component(range['high'])

      # Get range type prefix
      range_type = get_range_type_prefix(range)

      # Create params hash for formatting
      params = {
        range_type:,
        low: { value: low_value, unit: low_unit },
        high: { value: high_value, unit: high_unit },
        type_text: range['type'].is_a?(Hash) ? range['type']['text'] : nil
      }

      # Format based on available values
      format_range_based_on_values(params)
    rescue => e
      Rails.logger.error("Error in format_numeric_range: #{e.message}")
      ''
    end

    # Helper method to format range based on which values are available
    def format_range_based_on_values(params)
      range_type = params[:range_type]
      low_value = params[:low][:value]
      low_unit = params[:low][:unit]
      high_value = params[:high][:value]
      high_unit = params[:high][:unit]

      if low_value && high_value
        format_low_high_range(params)
      elsif low_value
        unit_str = low_unit.empty? ? '' : " #{low_unit}"
        "#{range_type}>= #{low_value}#{unit_str}"
      elsif high_value
        unit_str = high_unit.empty? ? '' : " #{high_unit}"
        "#{range_type}<= #{high_value}#{unit_str}"
      else
        ''
      end
    end

    # Format range with both low and high values
    def format_low_high_range(params)
      range_type = params[:range_type]
      low_value = params[:low][:value]
      low_unit = params[:low][:unit]
      high_value = params[:high][:value]
      high_unit = params[:high][:unit]

      if !low_unit.empty? || !high_unit.empty?
        format_range_with_units(params)
      else
        "#{range_type}#{low_value} - #{high_value}"
      end
    end

    # Helper method to format range with units
    def format_range_with_units(params)
      range_type = params[:range_type]
      low_value = params[:low][:value]
      low_unit = params[:low][:unit]
      high_value = params[:high][:value]
      high_unit = params[:high][:unit]

      # Determine which unit to display (prefer high's unit, fall back to low's unit)
      final_unit = if !high_unit.empty?
                     high_unit
                   elsif !low_unit.empty?
                     low_unit
                   else
                     ''
                   end

      # Only show the unit on the last value
      unit_str = final_unit.empty? ? '' : " #{final_unit}"

      # Format the range with units only at the end
      "#{range_type}#{low_value} - #{high_value}#{unit_str}"
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

    # Logs the distribution of test codes found in the records for analytics purposes
    # This helps identify which test codes are common and might be worth filtering in
    def log_test_code_distribution(records)
      # Count occurrence of each test code
      test_code_counts = Hash.new(0)
      records.each do |record|
        test_code = record.attributes.test_code
        test_code_counts[test_code] += 1 if test_code.present?
      end

      # Only log if we have test codes
      return if test_code_counts.empty?

      # Sort by frequency (descending)
      sorted_counts = test_code_counts.sort_by { |_, count| -count }

      # Format for logging - code:count pairs
      code_count_pairs = sorted_counts.map { |code, count| "#{code}:#{count}" }

      # Log the distribution with useful context but no PII
      Rails.logger.info(
        {
          message: 'UHD test code distribution',
          test_code_distribution: code_count_pairs.join(','),
          total_codes: sorted_counts.size,
          total_records: records.size,
          service: 'unified_health_data'
        }
      )
    end
  end
end
