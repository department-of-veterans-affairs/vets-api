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

      # Modifies the appointment, extracting individual fields from the reason code text whenever possible.
      #
      # @param appointment [Hash] the appointment to modify
      def extract_reason_code_fields(appointment)
        # Return if the appointment is a CC request or not a request.
        # We consider appointments with requested_periods as requests.
        return if appointment[:kind] == 'cc' || appointment[:requested_periods].blank?

        # Retrieve the reason code text, or return if it is not present
        reason_code_text = appointment&.dig(:reason_code, :text)
        return if reason_code_text.nil?

        # Convert the text to a hash for querying, or return if no valid key value pairs are found
        reason_code_hash = reason_code_text.split('|')
                                           .select { |pair| pair.count(':') == 1 }
                                           .to_h { |pair| pair.split(':').map!(&:strip) }
        return if reason_code_hash.empty?

        # Extract contact fields from hash
        contact = extract_contact_fields(reason_code_hash)
        appointment[:contact] = contact unless contact.nil?

        # Extract additional appointment details from hash
        appointment[:additional_appointment_details] = reason_code_hash['comments'] if reason_code_hash.key?('comments')

        # Extract reason for appointment from hash
        reason = extract_reason_for_appointment(reason_code_hash)
        appointment[:reason_for_appointment] = reason unless reason.nil?

        # Extract preferred dates from hash
        preferred_dates = extract_preferred_dates(reason_code_hash)
        appointment[:preferred_dates] = preferred_dates unless preferred_dates.nil?
      end

      private

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
            # DateTime format reference in order of appearance:
            # %m - Date: Month of the year, zero-padded (01..12)
            # %d - Date: Day of the month, zero-padded (01..31)
            # %Y - Date: Year with century (can be negative, 4 digits at least, e.g. 1995, 2009)
            # %p - Time: Meridian indicator, uppercase ('AM' or 'PM')
            # %a - Weekday: The abbreviated name ('Sun')
            # %B - Date: The full month name ('January')
            # %-d - Date: Day of the month, no-padded (1..31)
            if date.end_with?('AM')
              dates.push(DateTime.strptime(date, '%m/%d/%Y %p').strftime('%a, %B %-d, %Y in the morning'))
            elsif date.end_with?('PM')
              dates.push(DateTime.strptime(date, '%m/%d/%Y %p').strftime('%a, %B %-d, %Y in the afternoon'))
            end
          end
          dates.presence
        end
      end
    end
  end
end
