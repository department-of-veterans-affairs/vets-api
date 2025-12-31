# frozen_string_literal: true

require_relative 'facility_name_resolver'
require_relative 'fhir_helpers'

module UnifiedHealthData
  module Adapters
    class OracleHealthPrescriptionAdapter
      include FhirHelpers
      # Parses an Oracle Health FHIR MedicationRequest into a UnifiedHealthData::Prescription
      #
      # @param resource [Hash] FHIR MedicationRequest resource from Oracle Health
      # @return [UnifiedHealthData::Prescription, nil] Parsed prescription or nil if invalid/filtered
      def parse(resource)
        return nil if resource.nil? || resource['id'].nil?

        category = categorize_medication(resource)

        # Filter out medications that should not be visible to Veterans
        return nil if %i[pharmacy_charges inpatient].include?(category)

        # Log uncategorized medications for review
        log_uncategorized_medication(resource) if category == :uncategorized

        UnifiedHealthData::Prescription.new(build_prescription_attributes(resource))
      rescue => e
        Rails.logger.error("Error parsing Oracle Health prescription: #{e.message}")
        nil
      end

      private

      # Logs uncategorized medications for review per specification requirement
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      def log_uncategorized_medication(resource)
        return unless Flipper.enabled?(:mhv_medications_v2_status_mapping)

        Rails.logger.warn(
          message: 'Oracle Health medication uncategorized',
          prescription_id_suffix: resource['id']&.to_s&.last(3) || 'unknown',
          reported_boolean: resource['reportedBoolean'],
          intent: resource['intent'],
          category_codes: extract_category(resource),
          service: 'unified_health_data'
        )
      end

      def build_prescription_attributes(resource)
        tracking_data = build_tracking_information(resource)
        dispenses_data = build_dispenses_information(resource)
        refill_metadata = extract_refill_submission_metadata_from_tasks(resource, dispenses_data)

        build_core_attributes(resource, dispenses_data)
          .merge(build_tracking_attributes(tracking_data))
          .merge(build_contact_and_source_attributes(resource, dispenses_data))
          .merge(dispenses: dispenses_data)
          .merge(refill_metadata)
      end

      # Builds core prescription attributes from the FHIR MedicationRequest resource.
      # Note: refill_submit_date is set to nil here and later overridden by
      # extract_refill_submission_metadata_from_tasks in build_prescription_attributes.
      # This allows refill_metadata to be computed after dispenses_data is available
      # (needed to determine if a subsequent dispense exists for the refill).
      def build_core_attributes(resource, dispenses_data = [])
        refill_status = extract_refill_status(resource, dispenses_data)
        {
          id: resource['id'],
          type: 'Prescription',
          refill_status:,
          refill_submit_date: nil,
          refill_date: extract_refill_date(resource),
          refill_remaining: extract_refill_remaining(resource),
          facility_name: extract_facility_name(resource),
          ordered_date: resource['authoredOn'],
          quantity: extract_quantity(resource),
          expiration_date: extract_expiration_date(resource),
          prescription_number: extract_prescription_number(resource),
          prescription_name: extract_prescription_name(resource),
          dispensed_date: nil, # Not available in FHIR
          station_number: extract_station_number(resource),
          is_refillable: extract_is_refillable(resource, refill_status),
          cmop_ndc_number: nil # Not available in Oracle Health yet, will get this when we get CMOP data
        }
      end

      def build_tracking_attributes(tracking_data)
        {
          is_trackable: tracking_data.any?,
          tracking: tracking_data
        }
      end

      def build_contact_and_source_attributes(resource, dispenses_data = [])
        refill_status = extract_refill_status(resource, dispenses_data)
        prescription_source = extract_prescription_source(resource)
        {
          instructions: extract_instructions(resource),
          facility_phone_number: nil, # Not typically available in standard FHIR MedicationRequest
          cmop_division_phone: nil,
          dial_cmop_division_phone: nil,
          prescription_source:,
          category: extract_category(resource),
          disclaimer: nil,
          provider_name: extract_provider_name(resource),
          indication_for_use: extract_indication_for_use(resource),
          remarks: extract_remarks(resource),
          disp_status: map_refill_status_to_disp_status(refill_status, prescription_source)
        }
      end

      def build_tracking_information(resource)
        contained_resources = resource['contained'] || []
        dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }

        dispenses.filter_map do |dispense|
          extract_tracking_from_dispense(resource, dispense)
        end
      end

      def extract_tracking_from_dispense(resource, dispense)
        identifiers = dispense['identifier'] || []

        tracking_number = find_identifier_value(identifiers, 'Tracking Number')
        return nil unless tracking_number # Only create tracking record if we have a tracking number

        prescription_number = find_identifier_value(identifiers, 'Prescription Number')
        carrier = find_identifier_value(identifiers, 'Carrier')
        shipped_date = find_identifier_value(identifiers, 'Shipped Date')

        {
          prescription_name: extract_prescription_name(resource),
          prescription_number: prescription_number || extract_prescription_number(resource),
          ndc_number: extract_ndc_number(dispense),
          prescription_id: resource['id'],
          tracking_number:,
          shipped_date:,
          carrier:,
          other_prescriptions: [] # TODO: Implement logic to find other prescriptions in this package
        }
      end

      def build_dispenses_information(resource)
        contained_resources = resource['contained'] || []
        dispenses = contained_resources.select { |c| c.is_a?(Hash) && c['resourceType'] == 'MedicationDispense' }

        dispenses.map do |dispense|
          {
            status: dispense['status'],
            refill_date: dispense['whenHandedOver'],
            when_prepared: dispense['whenPrepared'],
            when_handed_over: dispense['whenHandedOver'],
            facility_name: facility_resolver.resolve_facility_name(dispense),
            instructions: extract_sig_from_dispense(dispense),
            quantity: dispense.dig('quantity', 'value'),
            medication_name: dispense.dig('medicationCodeableConcept', 'text'),
            id: dispense['id'],
            refill_submit_date: nil,
            prescription_number: nil,
            remarks: nil,
            disclaimer: nil
          }.merge(cmop_dispense_fields)
        end
      end

      # CMOP-related fields not available in Oracle Health yet
      # Extracted to separate method to keep build_dispenses_information under line limit
      #
      # @return [Hash] Hash of CMOP-related nil fields
      def cmop_dispense_fields
        {
          cmop_division_phone: nil,
          cmop_ndc_number: nil,
          dial_cmop_division_phone: nil
        }
      end

      # Extracts refill submission metadata from Task resources during prescription parsing
      # Sets refill_submit_date based on successful refill requests
      #
      # Conditions for a valid submitted refill:
      # 1. Task with intent='order', status='requested', and matching focus.reference exists
      # 2. No MedicationDispense with whenPrepared or whenHandedOver date after Task.executionPeriod.start
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param dispenses_data [Array<Hash>] Array of dispense data for checking subsequent dispenses
      # @return [Hash] Hash containing refill_submit_date if applicable
      def extract_refill_submission_metadata_from_tasks(resource, dispenses_data = [])
        contained_resources = resource['contained'] || []
        medication_request_id = resource['id']

        # Find successful refill tasks: intent='order', status='requested', matching focus reference
        successful_refill_tasks = contained_resources.select do |c|
          c.is_a?(Hash) &&
            c['resourceType'] == 'Task' &&
            c['intent'] == 'order' &&
            c['status'] == 'requested' &&
            task_references_medication_request?(c, medication_request_id)
        end

        return {} if successful_refill_tasks.empty?

        # Get most recent task by executionPeriod.start
        most_recent_task = successful_refill_tasks.max_by do |task|
          parse_date_or_epoch(task.dig('executionPeriod', 'start'))
        end

        task_submit_date = most_recent_task.dig('executionPeriod', 'start')
        return {} unless task_submit_date

        # Validate date format before returning - reject invalid dates
        parsed_date = parse_date_or_epoch(task_submit_date)
        return {} if parsed_date == Time.zone.at(0)

        return {} if subsequent_dispense?(task_submit_date, dispenses_data)

        { refill_submit_date: task_submit_date }
      end

      # Validates that Task.focus.reference matches the parent MedicationRequest.id
      #
      # @param task [Hash] FHIR Task resource
      # @param medication_request_id [String] Parent MedicationRequest ID
      # @return [Boolean] True if Task references the parent MedicationRequest
      def task_references_medication_request?(task, medication_request_id)
        return false unless medication_request_id

        focus_reference = task.dig('focus', 'reference')
        return false unless focus_reference

        # Task.focus.reference should be in format "MedicationRequest/<id>"
        expected_reference = "MedicationRequest/#{medication_request_id}"
        focus_reference == expected_reference
      end

      # Checks if there's a MedicationDispense with whenPrepared or whenHandedOver
      # date after the Task.executionPeriod.start
      #
      # @param task_start_time [String] ISO 8601 date string from Task.executionPeriod.start
      # @param dispenses_data [Array<Hash>] Array of dispense data with when_prepared and when_handed_over
      # @return [Boolean] True if a subsequent dispense exists
      def subsequent_dispense?(task_start_time, dispenses_data)
        return false unless dispenses_data.present? && task_start_time.present?

        task_time = parse_date_or_epoch(task_start_time)

        dispenses_data.any? do |dispense|
          when_prepared = dispense[:when_prepared]
          when_handed_over = dispense[:when_handed_over]

          # Check if either whenPrepared or whenHandedOver is after the task submission
          (when_prepared.present? && parse_date_or_epoch(when_prepared) > task_time) ||
            (when_handed_over.present? && parse_date_or_epoch(when_handed_over) > task_time)
        end
      end

      def extract_refill_date(resource)
        dispense = find_most_recent_medication_dispense(resource['contained'])
        return dispense['whenHandedOver'] if dispense&.dig('whenHandedOver')

        nil
      end

      def extract_refill_remaining(resource)
        # non-va meds are never refillable
        return 0 if non_va_med?(resource)

        repeats_allowed = resource.dig('dispenseRequest', 'numberOfRepeatsAllowed') || 0
        # subtract dispenses in completed status, except for the first fill
        dispenses_completed = if resource['contained']
                                resource['contained'].count do |c|
                                  c['resourceType'] == 'MedicationDispense' && c['status'] == 'completed'
                                end
                              else
                                0
                              end
        remaining = repeats_allowed - [dispenses_completed - 1, 0].max
        remaining.positive? ? remaining : 0
      end

      # Extracts and normalizes MedicationRequest status to VistA-compatible values
      # Checks for successful submitted refills based on Task resources
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param dispenses_data [Array<Hash>] Array of dispense data for checking subsequent dispenses
      # @return [String] VistA-compatible status value
      def extract_refill_status(resource, dispenses_data = [])
        # Check if there's a successful submitted refill (no subsequent dispense)
        contained_resources = resource['contained'] || []
        medication_request_id = resource['id']

        # Find successful refill tasks: intent='order', status='requested', matching focus reference
        successful_refill_tasks = contained_resources.select do |c|
          c.is_a?(Hash) &&
            c['resourceType'] == 'Task' &&
            c['intent'] == 'order' &&
            c['status'] == 'requested' &&
            task_references_medication_request?(c, medication_request_id)
        end

        if successful_refill_tasks.any?
          # Get most recent task by executionPeriod.start
          most_recent_task = successful_refill_tasks.max_by do |task|
            parse_date_or_epoch(task.dig('executionPeriod', 'start'))
          end

          task_submit_date = most_recent_task.dig('executionPeriod', 'start')
          return 'submitted' if task_submit_date && !subsequent_dispense?(task_submit_date, dispenses_data)
        end

        normalize_to_legacy_vista_status(resource)
      end

      # Maps refill_status to user-friendly disp_status for display
      # When disp_status is nil (UHD service), derive it from refill_status
      #
      # @param refill_status [String] Internal refill status code
      # @param prescription_source [String] Source of prescription (VA, NV, etc.)
      # @return [String] User-friendly display status
      def map_refill_status_to_disp_status(refill_status, prescription_source)
        # Special case: active + Non-VA source
        return 'Active: Non-VA' if refill_status == 'active' && prescription_source == 'NV'

        # Standard mapping
        case refill_status
        when 'active'
          'Active'
        when 'submitted'
          'Active: Submitted'
        when 'refillinprocess'
          'Active: Refill in Process'
        when 'providerHold'
          'Active: On hold'
        when 'discontinued'
          'Discontinued'
        when 'expired'
          'Expired'
        when 'unknown', 'pending'
          'Unknown'
        else
          # Fallback for unexpected values
          Rails.logger.warn("Unexpected refill_status for disp_status mapping: #{refill_status}")
          'Unknown'
        end
      end

      # Maps Oracle Health FHIR MedicationRequest status to VistA-equivalent status
      # Based on legacy VistA status mapping requirements
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [String] VistA-compatible status value
      def normalize_to_legacy_vista_status(resource)
        mr_status = resource['status']
        refills_remaining = extract_refill_remaining(resource)
        expiration_date = parse_expiration_date_utc(resource)
        has_in_progress_dispense = most_recent_dispense_in_progress?(resource)

        normalized_status = map_fhir_status_to_vista(
          mr_status,
          refills_remaining,
          expiration_date,
          has_in_progress_dispense,
          resource
        )

        log_status_normalization(resource, mr_status, normalized_status, refills_remaining, has_in_progress_dispense)

        normalized_status
      end

      # Maps FHIR MedicationRequest status to VistA equivalent using business rules
      #
      # @param mr_status [String] FHIR MedicationRequest.status
      # @param refills_remaining [Integer] Number of refills remaining
      # @param expiration_date [Time, nil] Parsed UTC expiration date
      # @param has_in_progress_dispense [Boolean] Whether the most recent dispense is in-progress
      # @return [String] VistA-compatible status value
      def map_fhir_status_to_vista(mr_status, refills_remaining, expiration_date, has_in_progress_dispense,
                                   resource = nil)
        case mr_status
        when 'active'
          normalize_active_status(refills_remaining, expiration_date, has_in_progress_dispense, resource)
        when 'on-hold'
          'providerHold'
        when 'cancelled', 'entered-in-error', 'stopped'
          'discontinued'
        when 'completed'
          normalize_completed_status(expiration_date)
        when 'draft'
          'pending'
        when 'unknown'
          'unknown'
        else
          Rails.logger.warn("Unexpected MedicationRequest status: #{mr_status}")
          'unknown'
        end
      end

      # Logs status normalization details for monitoring
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @param original_status [String] Original FHIR status
      # @param normalized_status [String] Normalized VistA status
      # @param refills_remaining [Integer] Number of refills remaining
      # @param has_in_progress_dispense [Boolean] Whether the most recent dispense is in-progress
      def log_status_normalization(resource, original_status, normalized_status, refills_remaining,
                                   has_in_progress_dispense)
        prescription_id_suffix = resource['id']&.to_s&.last(3) || 'unknown'

        Rails.logger.info(
          message: 'Oracle Health status normalized',
          prescription_id_suffix:,
          original_status:,
          normalized_status:,
          refills_remaining:,
          has_in_progress_dispense:,
          service: 'unified_health_data'
        )
      end

      # Determines VistA status for 'active' MedicationRequest based on business rules
      #
      # @param refills_remaining [Integer] Number of refills remaining
      # @param expiration_date [Time, nil] Parsed UTC expiration date
      # @param has_in_progress_dispense [Boolean] Whether the most recent dispense is in-progress
      # @return [String] VistA status value
      def normalize_active_status(refills_remaining, expiration_date, has_in_progress_dispense, resource = nil)
        # Rule: Expired more than 120 days ago → discontinued
        return 'discontinued' if expiration_date && expiration_date < 120.days.ago.utc

        # Rule: No refills remaining → expired (UNLESS it's a Non-VA medication)
        # Non-VA meds are always reported with 0 refills but should still be 'active' if status is 'active'
        is_non_va = resource && non_va_med?(resource)
        return 'expired' if refills_remaining.zero? && !is_non_va

        # Rule: Most recent dispense is in-progress → refillinprocess
        return 'refillinprocess' if has_in_progress_dispense

        # Default: active
        'active'
      end

      # Determines VistA status for 'completed' MedicationRequest
      #
      # @param expiration_date [Time, nil] Parsed UTC expiration date
      # @return [String] VistA status value ('expired' or 'discontinued')
      def normalize_completed_status(expiration_date)
        # If no expiration date, we can't determine if it's expired based on date
        # A completed med without an expiration date should be discontinued
        return 'discontinued' if expiration_date.nil?

        if expiration_date < 120.days.ago.utc
          'discontinued'
        else
          'expired'
        end
      end

      # Checks if the most recent MedicationDispense has an in-progress status
      # In-progress statuses: preparation, in-progress, on-hold
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Boolean] True if most recent dispense is in-progress
      def most_recent_dispense_in_progress?(resource)
        most_recent_dispense = find_most_recent_medication_dispense(resource['contained'])
        return false if most_recent_dispense.nil?

        in_progress_statuses = %w[preparation in-progress on-hold]
        in_progress_statuses.include?(most_recent_dispense['status'])
      end

      # Parses validityPeriod.end to UTC Time object for comparison
      #
      # @param resource [Hash] FHIR MedicationRequest resource
      # @return [Time, nil] Parsed UTC time or nil if not available/invalid
      def parse_expiration_date_utc(resource)
        expiration_string = resource.dig('dispenseRequest', 'validityPeriod', 'end')
        return nil if expiration_string.blank?

        # Oracle Health dates are in Zulu time (UTC)
        parsed_time = Time.zone.parse(expiration_string)
        if parsed_time.nil?
          Rails.logger.warn("Failed to parse expiration date '#{expiration_string}': invalid date format")
          return nil
        end

        parsed_time.utc
      rescue ArgumentError => e
        Rails.logger.warn("Failed to parse expiration date '#{expiration_string}': #{e.message}")
        nil
      end

      def extract_facility_name(resource)
        dispense = find_most_recent_medication_dispense(resource['contained'])
        facility_resolver.resolve_facility_name(dispense)
      end

      def extract_quantity(resource)
        # Primary: dispenseRequest.quantity.value
        quantity = resource.dig('dispenseRequest', 'quantity', 'value')
        return quantity if quantity

        # Fallback: check contained MedicationDispense
        dispense = find_most_recent_medication_dispense(resource['contained'])
        return dispense.dig('quantity', 'value') if dispense

        nil
      end

      def extract_expiration_date(resource)
        resource.dig('dispenseRequest', 'validityPeriod', 'end')
      end

      def extract_prescription_number(resource)
        # Look for identifier with prescription number
        identifiers = resource['identifier'] || []
        prescription_id = identifiers.find { |id| id['system']&.include?('prescription') }
        prescription_id ? prescription_id['value'] : resource['id']
      end

      def extract_prescription_name(resource)
        resource.dig('medicationCodeableConcept', 'text') ||
          resource.dig('medicationReference', 'display')
      end

      def extract_station_number(resource)
        dispense = find_most_recent_medication_dispense(resource['contained'])
        raw_station_number = dispense&.dig('location', 'display')
        return nil unless raw_station_number

        # Extract first 3 digits from format like "556-RX-MAIN-OP"
        match = raw_station_number.match(/^(\d{3})/)
        if match
          match[1]
        else
          Rails.logger.warn("Unable to extract 3-digit station number from: #{raw_station_number}")
          raw_station_number
        end
      end

      def extract_is_refillable(resource, refill_status)
        refillable = true

        refillable = false if non_va_med?(resource) # non VA meds are never refillable
        refillable = false unless resource['status'] == 'active' # must be active
        refillable = false unless prescription_not_expired?(resource) # must not be expired
        refillable = false unless extract_refill_remaining(resource).positive? # must have refills remaining
        refillable = false if find_most_recent_medication_dispense(resource['contained']).nil?
        refillable = false if most_recent_dispense_in_progress?(resource) # must not have in-progress dispense
        refillable = false if refill_status == 'submitted' # must not have pending refill request

        refillable
      end

      def extract_instructions(resource)
        dosage_instructions = resource['dosageInstruction'] || []
        return nil if dosage_instructions.empty?

        first_instruction = dosage_instructions.first

        # Use patientInstruction if available (more user-friendly)
        return first_instruction['patientInstruction'] if first_instruction['patientInstruction']

        # Otherwise use text
        return first_instruction['text'] if first_instruction['text']

        # Build from components
        build_instruction_text(first_instruction)
      end

      def extract_prescription_source(resource)
        non_va_med?(resource) ? 'NV' : 'VA'
      end

      def extract_provider_name(resource)
        resource.dig('requester', 'display')
      end

      def extract_indication_for_use(resource)
        # Extract indication from FHIR MedicationRequest.reasonCode
        reason_codes = resource['reasonCode'] || []
        return nil if reason_codes.empty?

        # reasonCode is an array of CodeableConcept objects
        # Concatenate text from all reasonCode entries
        texts = reason_codes.filter_map { |reason_code| reason_code['text'] }
        texts.join('; ') if texts.any?
      end

      def extract_remarks(resource)
        # Concatenate all MedicationRequest.note.text fields
        notes = resource['note'] || []
        return nil if notes.empty?

        note_texts = notes.filter_map { |note| note['text'].presence }
        return nil if note_texts.empty?

        note_texts.join(' ')
      end

      def prescription_not_expired?(resource)
        expiration_date = extract_expiration_date(resource)
        return false unless expiration_date # No expiration date = not refillable for safety

        begin
          parsed_date = Time.zone.parse(expiration_date)
          return parsed_date&.> Time.zone.now if parsed_date

          # If we get here, parsing returned nil (invalid date)
          log_invalid_expiration_date(resource, expiration_date)
          false
        rescue ArgumentError
          log_invalid_expiration_date(resource, expiration_date)
          false
        end
      end

      def facility_resolver
        @facility_resolver ||= FacilityNameResolver.new
      end
    end
  end
end
