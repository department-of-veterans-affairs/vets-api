# frozen_string_literal: true

module VAOS
  module V2
    # This class contains the logic for extracting extra fields from reason codes and updating the appointment.
    class AppointmentsReasonCodeService
      # Modifies the appointment, extracting individual fields from the reason code text whenever possible.
      #
      # @param appointment [Hash] the appointment to modify
      def extract_reason_code_fields(appointment)
        # Return if the appointment is not a request or is a CC request
        return if archetype_service.booked?(appointment) || archetype_service.cc?(appointment)

        # Retrieve the reason code text, or return if it is not present
        reason_code_text = appointment&.dig(:reason_code, :text)
        return if reason_code_text.nil?

        # Convert the text to a hash for querying, or return if no valid key value pairs are found
        reason_code_hash = reason_code_text.split('|')
                                           .select { |pair| pair.count(':') == 1 }
                                           .to_h { |pair| pair.split(':').map!(&:strip) }
        return if reason_code_hash.empty?

        # Extract contact fields from hash
        if reason_code_hash.key?('phone number') || reason_code_hash.key?('email')
          contact_info = []
          contact_info.push({ system: 'phone', value: reason_code_hash['phone number'] })
          contact_info.push({ system: 'email', value: reason_code_hash['email'] })
          appointment[:contact] = { telecom: contact_info }
        end
      end

      def archetype_service
        @archetype_service ||= VAOS::V2::AppointmentsArchetypeService.new
      end
    end
  end
end
