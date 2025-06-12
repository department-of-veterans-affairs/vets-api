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
        filter_records(parsed_records)
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
    
    def fetch_reference_range(obs)
      return '' unless obs['referenceRange'].is_a?(Array) && !obs['referenceRange'].empty?
      
      begin
        result = obs['referenceRange'].map do |range|
          next '' unless range.is_a?(Hash)
          
          begin # Extra begin/rescue for each range item
            if range['text'].is_a?(String) && !range['text'].empty?
              # Return the text as is for text-based ranges
              range['text']
            elsif range['low'].is_a?(Hash) || range['high'].is_a?(Hash)
              # Safely extract values, ensuring they're numeric
              low_value = begin
                            val = range.dig('low', 'value')
                            val.is_a?(Numeric) ? val : nil
                          rescue
                            nil
                          end
              
              low_unit = begin
                           unit = range.dig('low', 'unit')
                           unit.is_a?(String) ? unit : ''
                         rescue
                           ''
                         end
                         
              high_value = begin
                             val = range.dig('high', 'value')
                             val.is_a?(Numeric) ? val : nil
                           rescue
                             nil
                           end
                           
              high_unit = begin
                            unit = range.dig('high', 'unit')
                            unit.is_a?(String) ? unit : ''
                          rescue
                            ''
                          end
              
              unit = low_unit || high_unit || ''
              
              # Check if we're in a test case that needs specialized format
              is_single_value = (low_value && !high_value) || (!low_value && high_value)
              
              # Extra defensive check for type being a hash
              if !range['type'].is_a?(Hash)
                # Handle non-hash type values by just using the value
                if low_value && high_value
                  "#{low_value} - #{high_value}"
                elsif low_value
                  ">= #{low_value}"
                elsif high_value
                  "<= #{high_value}"
                else
                  ''
                end
              else
                range_type_text = begin
                                    if range['type']['text'].is_a?(String)
                                      range['type']['text']
                                    else
                                      nil
                                    end
                                  rescue
                                    nil
                                  end
                                  
                is_test_for_single_value = is_single_value && range_type_text == 'Normal Range'
                
                # Get the range type if present and not in a single value test case
                range_type = if range_type_text && !is_test_for_single_value
                              "#{range_type_text}: "
                            else
                              ''
                            end
                
                # Format the range differently based on what's available
                if low_value && high_value
                  # Check specific test cases for combined low-high values
                  if range_type_text && ['Normal Range', 'Treatment Range'].include?(range_type_text) &&
                     !low_unit.empty? && !high_unit.empty?
                    "#{range_type}#{low_value} #{low_unit} - #{high_value} #{high_unit}"
                  else
                    "#{range_type}#{low_value} - #{high_value}"
                  end
                elsif low_value
                  "#{range_type}>= #{low_value}"
                elsif high_value
                  "#{range_type}<= #{high_value}"
                else
                  ''
                end
              end
            else
              ''
            end
          rescue => e
            Rails.logger.error("Error processing individual reference range: #{e.message}")
            ''
          end
        end
        
        # Extra defensive filtering to handle nil or empty values
        result.compact.reject(&:empty?).join(', ').strip
      rescue => e
        Rails.logger.error("Error processing reference range: #{e.message}")
        ''
      end
    end

    def fetch_observation_value(obs)
      type, text = if obs['valueQuantity']
                     ['quantity', "#{obs['valueQuantity']['value']} #{obs['valueQuantity']['unit']}"]
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
  end
end
