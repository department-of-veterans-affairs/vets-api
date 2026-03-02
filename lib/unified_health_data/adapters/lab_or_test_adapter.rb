# frozen_string_literal: true

require_relative '../models/lab_or_test'
require_relative '../reference_range_formatter'
require_relative '../facility_service'
require_relative 'date_normalizer'
require_relative 'fhir_helpers'

module UnifiedHealthData
  module Adapters
    class LabOrTestAdapter # rubocop:disable Metrics/ClassLength
      include DateNormalizer
      include FhirHelpers

      ALLOWED_STATUSES = %w[final amended corrected appended].freeze
      LABS = 'labs_and_tests'

      # @param mr_log [MedicalRecords::MedicalRecordsLog, nil] Structured logger (nil = Rails.logger fallback)
      def initialize(mr_log: nil)
        @mr_log = mr_log
      end

      # HL7 v2-0074 diagnostic service section codes and LOINC codes to user-friendly display names
      TEST_CODE_DISPLAY_MAP = {
        'CH' => 'Chemistry and hematology',
        'MI' => 'Microbiology',
        'MB' => 'Microbiology',
        'SP' => 'Surgical Pathology',
        'CY' => 'Cytology',
        'EM' => 'Electron Microscopy',
        'LP29684-5' => 'Radiology'
      }.freeze

      def parse_labs(records)
        return [] if records.blank?

        filtered = records.select do |record|
          record['resource'] && record['resource']['resourceType'] == 'DiagnosticReport'
        end
        filtered.filter_map do |record|
          parse_single_record(record)
        rescue Common::Exceptions::BaseError
          raise
        rescue => e
          log_record_parse_failure(record, e)
          nil
        end
      end

      def parse_single_record(record)
        return nil if record.nil? || record['resource'].nil?

        # Filter out DiagnosticReports with disallowed status
        unless allowed_status?(record['resource']['status'])
          log_filtered_diagnostic_report(record, 'disallowed_status')
          return nil
        end

        contained = record['resource']['contained']
        code = get_code(record)
        encoded_data = get_encoded_data(record['resource'])
        observations = get_observations(record)

        # Log warnings before filtering out records
        log_warnings(record, encoded_data, observations)

        # Return nil if there's no code, and if there's no encoded data AND no valid observations
        unless code && (encoded_data.present? || observations.any?)
          log_filtered_diagnostic_report(record, 'no_valid_data')
          return nil
        end

        build_lab_or_test(record, code, encoded_data, observations, contained)
      end

      # Public method to extract station number from a record's contained resources.
      # Used by Service layer for cache pre-warming.
      #
      # @param record [Hash] A UHD record with 'resource' > 'contained'
      # @return [String, nil] Station number or nil if not found
      def extract_station_number_from_record(record)
        return nil if record.nil?

        contained = record.dig('resource', 'contained')
        extract_station_number(contained)
      end

      private

      def allowed_status?(status)
        ALLOWED_STATUSES.include?(status)
      end

      # Dual-path logging: structured mr_log when available, Rails.logger fallback otherwise.
      def log_adapter(level, structured_opts, fallback_message, fallback_opts = {})
        if @mr_log
          @mr_log.public_send(level, **structured_opts)
        else
          Rails.logger.public_send(level, fallback_message, fallback_opts.presence)
        end
      end

      def build_lab_or_test(record, code, encoded_data, observations, contained) # rubocop:disable Metrics/MethodLength
        resource = record['resource']
        date_completed_value, facility_timezone = resolve_date_and_timezone(resource, contained)

        UnifiedHealthData::LabOrTest.new(
          id: resource['id'],
          type: resource['resourceType'],
          display: format_display(resource),
          test_code: code,
          test_code_display: get_test_code_display(record, code),
          date_completed: date_completed_value,
          sort_date: normalize_date_for_sorting(date_completed_value),
          sample_tested: get_sample_tested(resource, contained),
          encoded_data:,
          location: get_location(record),
          ordered_by: get_ordered_by(record),
          comments: extract_comments(record),
          observations:,
          body_site: get_body_site(resource, contained),
          status: resource['status'],
          source: record['source'],
          facility_timezone:
        )
      end # rubocop:enable Metrics/MethodLength

      # Resolves date_completed and facility_timezone by extracting station number
      # and converting UTC to facility local time when possible
      def resolve_date_and_timezone(resource, contained)
        raw_date = get_date_completed(resource)
        station_number = extract_station_number(contained)
        facility_timezone = get_facility_timezone(station_number)
        date_completed = convert_to_facility_time(raw_date, facility_timezone)
        [date_completed, facility_timezone]
      end

      def log_warnings(record, encoded_data, observations)
        log_final_status_warning(record, record['resource']['status'], encoded_data, observations)
        log_missing_date_warning(record)
      end

      def log_filtered_diagnostic_report(record, reason)
        resource = record['resource']
        log_adapter(
          :info,
          { resource: LABS, action: 'filter', report_id: resource['id'],
            status: resource['status'], reason:, filtering: true },
          "Filtered DiagnosticReport: id=#{resource['id']}, status=#{resource['status']}, reason=#{reason}",
          { service: 'unified_health_data', filtering: true }
        )
        StatsD.increment('unified_health_data.lab_or_test.filtered_diagnostic_report',
                         tags: ["reason:#{reason}"])
      end

      def log_filtered_observations(record, filtered_count, total_count)
        resource = record['resource']
        log_adapter(
          :info,
          { resource: LABS, action: 'filter_observations', report_id: resource['id'],
            filtered: filtered_count, total: total_count, filtering: true },
          "Filtered #{filtered_count}/#{total_count} Observations from DiagnosticReport #{resource['id']}",
          { service: 'unified_health_data', filtering: true }
        )
        # Increment the counter once per DiagnosticReport that has filtered observations
        StatsD.increment('unified_health_data.lab_or_test.filtered_observations')
      end

      # Logs when an individual record fails to parse. Isolates one bad record from
      # killing the entire batch so the veteran still sees the rest of their results.
      def log_record_parse_failure(record, error)
        report_id = record.dig('resource', 'id')
        log_adapter(
          :error,
          { resource: LABS, action: 'parse', anomaly: 'record_parse_failure',
            report_id:, error_class: error.class.name, error_message: error.message },
          "Failed to parse DiagnosticReport #{report_id}: #{error.class} - #{error.message}",
          { service: 'unified_health_data' }
        )
        StatsD.increment('unified_health_data.lab_or_test.parse_failure')
      end

      # Logs when an individual observation within a DiagnosticReport fails to parse.
      # Isolates one bad observation so the rest of the record's observations are still returned.
      def log_observation_parse_failure(record, obs, error)
        report_id = record.dig('resource', 'id')
        observation_id = obs['id']
        log_adapter(
          :error,
          { resource: LABS, action: 'parse', anomaly: 'observation_parse_failure',
            report_id:, observation_id:, error_class: error.class.name, error_message: error.message },
          "Failed to parse Observation #{observation_id} in DiagnosticReport #{report_id}: " \
          "#{error.class} - #{error.message}",
          { service: 'unified_health_data' }
        )
        StatsD.increment('unified_health_data.lab_or_test.observation_parse_failure')
      end

      def log_final_status_warning(record, status, encoded_data, observations)
        return unless status == 'final' && encoded_data.blank? && observations.blank?

        report_id = record['resource']['id']
        if @mr_log
          @mr_log.warn(resource: LABS, action: 'parse', anomaly: 'final_status_empty_data', report_id:)
        else
          patient_ref = record['resource']&.dig('subject', 'reference')
          patient_last_four = patient_ref&.split('/')&.last&.last(4) || 'unknown'
          Rails.logger.warn(
            "DiagnosticReport #{report_id} has status 'final' but is missing " \
            "both encoded data and observations (Patient: #{patient_last_four})",
            { service: 'unified_health_data' }
          )
        end
        StatsD.increment('unified_health_data.lab_or_test.final_status_empty_data')
      end

      def log_missing_date_warning(record)
        resource = record['resource']
        effective_date_time = resource['effectiveDateTime']
        effective_period = resource['effectivePeriod']

        detail = if effective_date_time.blank? && effective_period.blank?
                   'missing effectiveDateTime and effectivePeriod'
                 elsif effective_period.present? && effective_period['start'].blank?
                   'missing effectivePeriod.start'
                 end
        return unless detail

        log_adapter(
          :warn,
          { resource: LABS, action: 'parse', anomaly: 'missing_date', report_id: resource['id'], detail: },
          "DiagnosticReport #{resource['id']} is #{detail}",
          { service: 'unified_health_data' }
        )
      end

      def get_location(record)
        contained = record.dig('resource', 'contained')
        return nil if contained.nil?

        performers = record.dig('resource', 'performer') || []
        performer_ref_ids = performers.map { |p| get_reference_id(p['reference']) }.compact

        # Find matching Organization or Location
        match = contained.find do |r|
          %w[Organization Location].include?(r['resourceType']) &&
            performer_ref_ids.include?(r['id'])
        end

        return match['name'] if match&.dig('name')

        # Fallback: first Organization
        contained.find { |r| r['resourceType'] == 'Organization' }&.dig('name')
      end

      def get_code(record)
        return nil if record['resource']['category'].blank?

        coding = record['resource']['category'].find do |category|
          category['coding'].present? && category['coding'][0]['code'] != 'LAB'
        end
        coding ? coding['coding'][0]['code'] : nil
      end

      # Normalize code for display mapping only (preserves raw code in test_code field)
      # Extracts 2-letter code from VistA URN format: "urn:va:lab-category:MI" -> "MI"
      def normalize_code_for_display(code)
        return code if code.nil?

        code.match(/urn:va:lab-category:(\w+)/)&.captures&.first || code
      end

      # Get the display name for a test code with fallback chain:
      # 1. Check TEST_CODE_DISPLAY_MAP (using normalized code)
      # 2. Fall back to category.coding.display from the FHIR data
      # 3. Fall back to category.text from the FHIR data
      # 4. Final fallback: the normalized code itself
      def get_test_code_display(record, code)
        normalized_code = normalize_code_for_display(code)

        # First, check our explicit mapping
        return TEST_CODE_DISPLAY_MAP[normalized_code] if TEST_CODE_DISPLAY_MAP.key?(normalized_code)

        # Fall back to display/text from the category coding in FHIR data
        category_display = get_category_display(record)
        return category_display if category_display.present?

        # Final fallback: use the normalized code
        normalized_code
      end

      # Extract display or text from the category that has the test code
      def get_category_display(record)
        return nil if record['resource']['category'].blank?

        category = record['resource']['category'].find do |cat|
          cat['coding'].present? && cat['coding'][0]['code'] != 'LAB'
        end
        return nil unless category

        # Try coding.display first, then category.text
        extract_codeable_concept_display(category, prefer: :coding)
      end

      def extract_comments(record)
        resource = record['resource']
        comments = []

        # Extract comments from DiagnosticReport extensions (VistA labComment extensions)
        if resource['extension'].present?
          extension_comments = resource['extension'].filter_map { |ext| ext['valueString'] }
          comments.concat(extension_comments)
        end

        # Extract comments from ServiceRequest.note[].text in contained resources (Oracle Health)
        if resource['basedOn'].present? && resource['contained'].present?
          resource['basedOn'].each do |based_on|
            service_request = resource['contained'].find do |r|
              r['resourceType'] == 'ServiceRequest' && r['id'] == get_reference_id(based_on['reference'])
            end

            next unless service_request&.dig('note').is_a?(Array)

            note_comments = service_request['note'].filter_map { |note| note['text'] }
            comments.concat(note_comments)
          end
        end

        comments.presence
      end

      def get_body_site(resource, contained)
        return '' unless resource['basedOn']
        return '' if contained.nil?

        body_sites = []

        resource['basedOn'].each do |based_on|
          service_request = contained.find do |r|
            r['resourceType'] == 'ServiceRequest' && r['id'] == get_reference_id(based_on['reference'])
          end

          next unless service_request&.dig('bodySite')

          service_request['bodySite'].each do |body_site|
            # Prefer coding display (VistA uses this), fall back to CodeableConcept text (OH uses this)
            display = extract_codeable_concept_display(body_site, prefer: :coding)
            body_sites << display if display.present?
          end
        end

        body_sites.join(', ').strip
      end

      def get_sample_tested(record, contained)
        return '' unless record['specimen']
        return '' if contained.nil?

        specimen_references = if record['specimen'].is_a?(Hash)
                                [get_reference_id(record['specimen']['reference'])]
                              elsif record['specimen'].is_a?(Array)
                                record['specimen'].map { |specimen| get_reference_id(specimen['reference']) }
                              end

        specimens =
          specimen_references.map do |reference|
            specimen_object = contained.find do |resource|
              resource['resourceType'] == 'Specimen' && resource['id'] == reference
            end
            specimen_object&.dig('type', 'text')
          end

        specimens.compact.join(', ').strip
      end

      def get_observations(record)
        return [] if record['resource']['contained'].nil?

        all_observations = record['resource']['contained'].select do |resource|
          resource['resourceType'] == 'Observation'
        end
        filtered_count = 0

        valid_observations = all_observations.filter_map do |obs|
          # Filter out observations with disallowed status
          unless allowed_status?(obs['status'])
            filtered_count += 1
            next
          end

          begin
            build_observation(obs, record['resource']['contained'])
          rescue Common::Exceptions::BaseError
            raise
          rescue => e
            log_observation_parse_failure(record, obs, e)
            nil
          end
        end

        # Log and track filtered observations
        log_filtered_observations(record, filtered_count, all_observations.size) if filtered_count.positive?

        valid_observations
      end

      def build_observation(obs, contained)
        sample_tested = get_sample_tested(obs, contained)
        body_site = get_body_site(obs, contained)
        UnifiedHealthData::Observation.new(
          test_code: obs['code']['text'],
          value: format_observation_value(obs),
          reference_range: UnifiedHealthData::ReferenceRangeFormatter.format(obs),
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.compact || [],
          sample_tested:,
          body_site:
        )
      end

      def format_observation_value(obs)
        type, text = if obs['valueQuantity']
                       ['quantity', format_quantity_value(obs['valueQuantity'])]
                     elsif obs['valueCodeableConcept']
                       ['codeable-concept', obs['valueCodeableConcept']['text']]
                     elsif obs['valueString']
                       ['string', obs['valueString']]
                     elsif obs['valueDateTime']
                       ['date-time', obs['valueDateTime']]
                     elsif obs['valueAttachment']
                       log_adapter(
                         :error,
                         { resource: LABS, action: 'parse', anomaly: 'unsupported_value_type',
                           observation_id: obs['id'], value_type: 'Attachment' },
                         { message: "Observation with ID #{obs['id']} has unsupported value type: Attachment" }
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

      def get_ordered_by(record)
        contained = record.dig('resource', 'contained')
        return nil if contained.nil?

        service_request = contained.find { |r| r['resourceType'] == 'ServiceRequest' }
        requester = service_request&.dig('requester')
        return nil unless requester

        requester_id = get_reference_id(requester['reference'])
        practitioner = contained.find do |r|
          r['resourceType'] == 'Practitioner' && r['id'] == requester_id
        end

        if practitioner
          name = practitioner['name'].first
          "#{name['given'].join(' ')} #{name['family']}"
        else
          # OH records may include a display name on the requester when the Practitioner
          # is not embedded in the contained array
          requester['display']
        end
      end

      def get_reference_id(reference)
        return nil if reference.blank?
        # Some of the VistA data doesn't use the full reference format, and instead just has the ID,
        # so we need to handle both cases
        return reference if reference&.exclude?('/')

        reference.split('/').last
      end

      def format_display(resource)
        # Check presentedForm title first (e.g., radiology reports)
        title = resource['presentedForm']
                &.find { |form| form['contentType'] == 'text/plain' }
                &.dig('title')
        return title if title.present?

        service_request = resource['contained']&.find { |r| r['resourceType'] == 'ServiceRequest' }

        service_request&.dig('code', 'text').presence ||
          service_request&.dig('category', 0, 'coding', 0, 'display').presence ||
          resource.dig('code', 'text') ||
          ''
      end

      def get_encoded_data(resource)
        return '' unless resource['presentedForm']&.any?

        # Find the presentedForm item with contentType 'text/plain'
        presented_form = resource['presentedForm'].find { |form| form['contentType'] == 'text/plain' }
        return '' unless presented_form

        # Handle standard data field or extensions indicating data-absent-reason
        # Return empty string when data is absent (either with data-absent-reason extension or missing)
        presented_form['data'] || ''
      end

      def get_date_completed(resource)
        # Handle both effectiveDateTime and effectivePeriod formats
        if resource['effectiveDateTime']
          resource['effectiveDateTime']
        elsif resource['effectivePeriod']&.dig('start')
          resource['effectivePeriod']['start']
        # Fallback to report's creation date if no other dates available
        elsif resource['presentedForm']
          resource['presentedForm'].find { |form| form['contentType'] == 'text/plain' }&.dig('creation')
        end
      end

      # Extracts station number from contained resources using multiple fallback strategies
      # Fallback chain:
      #   1. Practitioner SN=XXX format (most explicit, Oracle Health)
      #   2. Practitioner plain 3-digit number with "OTHER" type (Oracle Health)
      #   3. Organization with VA OID system (VistA data via UHD)
      #
      # @param contained [Array<Hash>] Array of contained FHIR resources
      # @return [String, nil] Station number (e.g., '668') or nil if not found
      def extract_station_number(contained)
        return nil if contained.blank?

        # Try Practitioner identifiers first (Oracle Health data)
        station_number = extract_station_from_practitioner(contained)
        return station_number if station_number.present?

        # Fallback: Try Organization identifiers (VistA data via UHD)
        extract_station_from_organization(contained)
      end

      # Extracts station number from Practitioner identifiers
      # Used primarily for Oracle Health data
      # Priority: SN=XXX format > plain 3-digit with OTHER type
      #
      # @param contained [Array<Hash>] Array of contained FHIR resources
      # @return [String, nil] Station number or nil if not found
      def extract_station_from_practitioner(contained)
        practitioner = contained.find { |r| r['resourceType'] == 'Practitioner' }
        return nil unless practitioner&.dig('identifier')

        identifiers = practitioner['identifier']

        # Priority 1: SN=XXX format (most explicit)
        sn_identifier = identifiers.find { |i| (val = i['value']).present? && val.start_with?('SN=') }
        return sn_identifier['value'].sub('SN=', '') if sn_identifier

        # Priority 2: Station number with "OTHER" type (3 digits, optionally with letter suffix like 668A, 668GC)
        plain_identifier = identifiers.find do |i|
          (val = i['value']).present? && i.dig('type', 'text') == 'OTHER' && val.match?(/^\d{3}[A-Z]{0,2}$/i)
        end
        plain_identifier&.dig('value')
      end

      # Extracts station number from Organization identifiers
      # Used primarily for VistA data coming through UHD
      # Looks for identifiers with the VA OID system (urn:oid:2.16.840.1.113883.4.349)
      #
      # @param contained [Array<Hash>] Array of contained FHIR resources
      # @return [String, nil] Station number or nil if not found
      def extract_station_from_organization(contained)
        organization = contained.find { |r| r['resourceType'] == 'Organization' }
        return nil unless organization&.dig('identifier')

        organization['identifier'].each do |identifier|
          system = identifier['system']
          value = identifier['value']

          # VA OID system identifier contains station number
          # Example: {"system": "urn:oid:2.16.840.1.113883.4.349", "value": "989"}
          next unless system.to_s.include?('2.16.840.1.113883.4.349') && value.present?

          return value
        end

        nil
      end

      # Gets the facility timezone using the UHD FacilityService
      #
      # @param station_number [String] The station number (e.g., '668')
      # @return [String, nil] IANA timezone ID (e.g., 'America/Los_Angeles') or nil if not found
      def get_facility_timezone(station_number)
        return nil if station_number.blank?

        facility_service.get_facility_timezone(station_number)
      end

      def facility_service
        @facility_service ||= UnifiedHealthData::FacilityService.new
      end

      # Converts a UTC datetime string to facility local time
      #
      # @param date_string [String] ISO 8601 datetime string (e.g., '2023-11-06T18:32:00+00:00')
      # @param timezone [String] IANA timezone ID (e.g., 'America/Los_Angeles')
      # @return [String] ISO 8601 datetime string in facility local time, or original if conversion fails
      def convert_to_facility_time(date_string, timezone)
        return date_string if date_string.blank? || timezone.blank?

        begin
          # Parse the datetime and convert to the facility timezone
          parsed_time = DateTime.parse(date_string).to_time.utc
          local_time = parsed_time.in_time_zone(timezone)
          local_time.iso8601
        rescue ArgumentError, TypeError, TZInfo::InvalidTimezoneIdentifier, TZInfo::UnknownTimezone => e
          log_adapter(
            :warn,
            { resource: LABS, action: 'timezone_conversion', error_message: e.message, date_string:, timezone: },
            "Failed to convert time to facility timezone: #{e.message}",
            { service: 'unified_health_data', date_string:, timezone: }
          )
          date_string
        end
      end
    end
  end
end
