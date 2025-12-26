# frozen_string_literal: true

require_relative '../models/vital'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class VitalAdapter
      include DateNormalizer
      FHIR_RESOURCE_TYPES = {
        BUNDLE: 'Bundle',
        DIAGNOSTIC_REPORT: 'DiagnosticReport',
        DOCUMENT_REFERENCE: 'DocumentReference',
        LOCATION: 'Location',
        OBSERVATION: 'Observation',
        ORGANIZATION: 'Organization',
        PRACTITIONER: 'Practitioner'
      }.freeze

      VITAL_LOINC_CODES = {
        '85354-9' => 'BLOOD_PRESSURE',
        '9279-1' => 'RESPIRATION',
        '8302-2' => 'HEIGHT',
        '8310-5' => 'TEMPERATURE',
        '29463-7' => 'WEIGHT',
        '3141-9' => 'WEIGHT',
        '8480-6' => 'SYSTOLIC',
        '8462-4' => 'DIASTOLIC',
        '8867-4' => 'PULSE',
        '59408-5' => 'PULSE_OXIMETRY',
        '2708-6' => 'PULSE_OXIMETRY'
      }.freeze

      VITAL_UNIT_DISPLAY_TEXT = {
        BLOOD_PRESSURE: '',
        PULSE: ' beats per minute',
        HEART_RATE: ' beats per minute',
        RESPIRATION: ' breaths per minute',
        RESPIRATORY_RATE: ' breaths per minute',
        PULSE_OXIMETRY: '%',
        TEMPERATURE: ' °F',
        WEIGHT: ' pounds',
        BODY_WEIGHT: ' pounds',
        HEIGHT_FT: ' feet',
        HEIGHT_IN: ' inches',
        BODY_HEIGHT: ' inches',
        PAIN_SEVERITY: ''
      }.freeze

      def parse(records)
        return [] if records.blank?

        filtered = records.select do |record|
          record['resource'] && record['resource']['resourceType'] == 'Observation'
        end
        parsed = filtered.map { |record| parse_single_vital(record) }
        log_locations_found
        parsed.compact
      end

      def parse_single_vital(record)
        return nil if record.nil? || record['resource'].nil?

        resource = record['resource']
        record_type = get_type(resource)
        date_value = resource['effectiveDateTime'] || nil

        UnifiedHealthData::Vital.new(
          id: resource['id'],
          name: get_name(resource),
          type: record_type,
          date: date_value,
          sort_date: normalize_date_for_sorting(date_value),
          measurement: get_measurements(resource, record_type),
          location: extract_location(resource),
          notes: extract_notes(resource)
        )
      end

      private

      def location_tracking_array
        @location_tracking_array ||= []
      end

      def log_locations_found
        unless location_tracking_array.empty?
          # Log how many vital records had multiple locations
          # Log only the unique location sets found (and the count) to reduce log noise
          Rails.logger.info(
            message: "Multiple locations found for #{location_tracking_array.size} Vital records:",
            locations: location_tracking_array.uniq,
            service: 'unified_health_data'
          )
        end
      end

      def get_name(resource)
        resource.dig('code', 'text').humanize || resource.dig('code', 'coding', 0, 'display').humanize || ''
      end

      def get_type(record)
        VITAL_LOINC_CODES.each do |key, value|
          return value if record['code']['coding']&.any? { |coding| coding['code'] == key }
        end
        # If we reach here, no matching LOINC codes were found, log them and return 'OTHER'
        coding_info = record['code']['coding']&.map do |coding|
          "code: #{coding['code']}, display: #{coding['display'] || ''}" if coding['code']
        end
        Rails.logger.warn("Unknown LOINC codes for Vital record text: #{record['code']['text']}, #{coding_info}")
        'OTHER'
      end

      def array_and_has_items(item)
        item.is_a?(Array) && !item.empty?
      end

      def extract_notes(resource)
        return [] unless resource['note']

        if array_and_has_items(resource['note'])
          resource['note'].map { |note| note['text'] }.compact
        else
          [resource['note']['text']].compact
        end
      end

      def get_measurements(record, record_type)
        # Specific to both VistA + OH blood pressure Diastolic & Systolic records
        if array_and_has_items(record['component'])
          format_blood_pressure(record)
        # Specific to items with multiple units of measure, e.g. Weight in both kg and lbs
        elsif array_and_has_items(record['valueQuantity']['extension'])
          format_extension_measurements(record, record_type)
        else
          units = VITAL_UNIT_DISPLAY_TEXT[record_type.to_sym] || ''
          if record_type == 'HEIGHT'
            format_height(record)
          else
            "#{record['valueQuantity']['value']}#{units}" || nil
          end
        end
      rescue
        nil
      end

      # TODO: how to handle if multiple locations?
      def extract_location(record)
        # VistA - location is in the performer.extension array
        # OH also has a performer.extension array but the "performer" is the practitioner
        # Both OH + VistA - location is in the contained array, might be multiple listed,
        # OH has no definitive reference, unlike VistA
        if array_and_has_items(record['contained'])
          # For now just get the first one
          location_array = record['contained'].map do |res|
            res['resourceType'] == FHIR_RESOURCE_TYPES[:LOCATION] ? res['name'] : nil
          end.compact
          if location_array.size > 1
            locations = { 'locations found' => location_array.size, 'names' => location_array.join('; ') }
            location_tracking_array.push(locations)
          end
          location_array.first unless location_array.empty?
        end
      rescue
        nil
      end

      def format_blood_pressure(record)
        systolic_ref = {}
        diastolic_ref = {}
        record['component'].each do |item|
          if item['code']['coding']&.any? { |coding| coding['code'] == '8480-6' }
            systolic_ref = item
          elsif item['code']['coding']&.any? { |coding| coding['code'] == '8462-4' }
            diastolic_ref = item
          end
        end

        if systolic_ref && diastolic_ref
          "#{systolic_ref['valueQuantity']['value']}/#{diastolic_ref['valueQuantity']['value']}"
        end
      end

      def format_height(height_ref)
        ft_in = height_ref['valueQuantity']['value'].divmod(12)
        "#{ft_in[0]}#{VITAL_UNIT_DISPLAY_TEXT[:HEIGHT_FT]}, #{ft_in[1].round(1)}#{VITAL_UNIT_DISPLAY_TEXT[:HEIGHT_IN]}"
      end

      def format_extension_measurements(record, record_type)
        case record_type
        when 'HEIGHT'
          height_ref = record['valueQuantity']['extension'].find { |ext| ext['valueQuantity']['code'] == '[in_i]' }
          format_height(height_ref)
        when 'WEIGHT'
          lbs_ref = record['valueQuantity']['extension'].find { |ext| ext['valueQuantity']['code'] == '[lb_av]' }
          "#{lbs_ref['valueQuantity']['value']}#{VITAL_UNIT_DISPLAY_TEXT[:WEIGHT]}"
        when 'TEMPERATURE'
          temp_ref = record['valueQuantity']['extension'].find { |ext| ext['valueQuantity']['code'] == '[degF]' }
          "#{temp_ref['valueQuantity']['value']}#{VITAL_UNIT_DISPLAY_TEXT[:TEMPERATURE]}"
        # if other types with multiple entries, but not specifically differentiated, return the default valueQuantity
        else
          units = VITAL_UNIT_DISPLAY_TEXT[record_type.to_sym] || ''
          "#{record['valueQuantity']['value']}#{units}"
        end
      end

      def find_contained(record, reference, type = nil)
        return nil unless reference && record['contained']

        if reference.start_with?('#')
          # Reference is in the format #mhv-resourceType-id
          target_id = reference.delete_prefix('#')
          resource = record['contained'].detect { |res| res['id'] == target_id }
          nil unless resource && resource['resourceType'] == type
        else
          # Reference is in the format ResourceType/id
          type_id = reference.split('/')
          resource = record['contained'].detect { |res| res['id'] == type_id.last }
          return nil unless resource && (resource['resourceType'] == type_id.first || resource['resourceType'] == type)
        end
        resource
      end
    end
  end
end
