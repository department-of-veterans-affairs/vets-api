# frozen_string_literal: true

module VAOS
  module V2
    # This class contains the logic for extracting extra fields from reason codes and updating the appointment.
    class AppointmentsReasonCodeService
      # Reason code purpose text
      PURPOSE_TEXT = {
        'ROUTINEVISIT' => 'Routine/Follow-up',
        'MEDICALISSUE' => 'New medical issue',
        'QUESTIONMEDS' => 'Medication concern',
        'OTHER_REASON' => 'My reason isn’t listed'
      }.freeze

      # Preferred modality text
      MODALITY_TEXT = {
        'FACE TO FACE' => 'In person',
        'VIDEO' => 'Video',
        'TELEPHONE' => 'Phone'
      }.freeze

      # Input format for preferred dates
      # Example: "07/18/2024 AM"
      INPUT_FORMAT = '%m/%d/%Y %p'

      # Output format for preferred dates
      # Example: "Thu, July 18, 2024 in the ..."
      OUTPUT_FORMAT_AM = '%a, %B %-d, %Y in the morning'
      OUTPUT_FORMAT_PM = '%a, %B %-d, %Y in the afternoon'

      # Modifies the appointment, extracting individual fields from the reason code text whenever possible.
      #
      # @param appointment [Hash] the appointment to modify
      def extract_reason_code_fields(appointment) # rubocop:disable Metrics/MethodLength
        # Retrieve the reason code text, or return if it is not present
        reason_code_text = appointment&.dig(:reason_code, :text)
        return if reason_code_text.nil?

        appointment_kind = appointment[:kind]
        requested_periods = appointment[:requested_periods]

        # Community care appointments and requests
        if appointment_kind == 'cc'
          appointment[:patient_comments] = reason_code_text
          return
        end

        # Parse reason code text or return if no valid key value pairs are found
        reason_code_hash = parse_reason_code_text(reason_code_text)
        return if reason_code_hash.empty?

        # VA Direct Scheduling appointments
        # Note we check requested periods to ensure booked DS appointments and booked DS
        # appointments that are later cancelled are both processed here.
        if appointment_kind == 'clinic' && requested_periods.blank?
          comments = reason_code_hash['comments'] if reason_code_hash.key?('comments')
          reason = extract_reason_for_appointment(reason_code_hash)

        # VA appointment requests
        elsif requested_periods.present? && appointment_kind != 'cc'
          contact = extract_contact_fields(reason_code_hash)
          comments = reason_code_hash['comments'] if reason_code_hash.key?('comments')
          reason = extract_reason_for_appointment(reason_code_hash)
          preferred_dates = extract_preferred_dates(reason_code_hash)
          preferred_modality = extract_preferred_modality(reason_code_hash)
        end

        appointment[:contact] = contact unless contact.nil?
        appointment[:patient_comments] = comments unless comments.nil?
        appointment[:reason_for_appointment] = reason unless reason.nil?
        appointment[:preferred_dates] = preferred_dates unless preferred_dates.nil?
        appointment[:preferred_modality] = preferred_modality unless preferred_modality.nil?
      end

      private

      # Convert the reason code text to a hash for querying.
      #
      # @param reason_code_text [String] the reason code text
      # @return [Hash, nil] A hash containing the parsed values.
      def parse_reason_code_text(reason_code_text)
        reason_code_hash = {}
        kvps = reason_code_text.split('|')
        kvps.each do |kvp|
          segments = kvp.split(':')
          # Key value pairs consisting of two segments are valid
          if segments.count == 2
            reason_code_hash[segments[0].strip] = segments[1].strip
          # User comments may contain colons so valid comments may consist of >=2
          # segments. We take the string after the first colon as the comments value.
          elsif segments[0].strip == 'comments' && segments.count > 1
            reason_code_hash['comments'] = kvp.partition(':')[2].strip
          end
        end
        reason_code_hash
      end

      # Extract contact fields from the reason code hash if possible.
      #
      # @param reason_code_hash [Hash] the hash of reason code key value pairs
      # @return [Hash, nil] A hash containing the contact info, or nil if not possible.
      def extract_contact_fields(reason_code_hash)
        if reason_code_hash.key?('phone number') || reason_code_hash.key?('email')
          contact_info = []
          contact_info.push({ type: 'phone', value: reason_code_hash['phone number'] })
          contact_info.push({ type: 'email', value: reason_code_hash['email'] })
          { telecom: contact_info }
        end
      end

      # Extract reason for appointment from the reason code hash if possible.
      #
      # @param reason_code_hash [Hash] the hash of reason code key value pairs
      # @return [String, nil] The reason for appointment as a string, or nil if not possible.
      def extract_reason_for_appointment(reason_code_hash)
        if reason_code_hash.key?('reason code') && PURPOSE_TEXT.key?(reason_code_hash['reason code'])
          PURPOSE_TEXT[reason_code_hash['reason code']]
        # Direct schedule appointments also used 'reasonCode' as the key in the past so we need this as well
        elsif reason_code_hash.key?('reasonCode') && PURPOSE_TEXT.key?(reason_code_hash['reasonCode'])
          PURPOSE_TEXT[reason_code_hash['reasonCode']]
        end
      end

      # Extract preferred modality for appointment from the reason code hash if possible.
      #
      # @param reason_code_hash [Hash] the hash of reason code key value pairs
      # @return [String, nil] The preferred modality for appointment as a string, or nil if not possible.
      def extract_preferred_modality(reason_code_hash)
        if reason_code_hash.key?('preferred modality') && MODALITY_TEXT.key?(reason_code_hash['preferred modality'])
          MODALITY_TEXT[reason_code_hash['preferred modality']]
        end
      end

      # Extract preferred time from the reason code hash if possible.
      #
      # @param reason_code_hash [Hash] the hash of reason code key value pairs
      # @return [Array, nil] An array of the preferred times, or nil if not possible.
      def extract_preferred_dates(reason_code_hash)
        if reason_code_hash.key?('preferred dates')
          dates = []
          reason_code_hash['preferred dates'].split(',').each do |date|
            if date.end_with?('AM')
              dates.push(DateTime.strptime(date, INPUT_FORMAT).strftime(OUTPUT_FORMAT_AM))
            elsif date.end_with?('PM')
              dates.push(DateTime.strptime(date, INPUT_FORMAT).strftime(OUTPUT_FORMAT_PM))
            end
          end
          dates.presence
        end
      end
    end
  end
end
