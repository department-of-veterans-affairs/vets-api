# frozen_string_literal: true

module VAOS
  module V2
    # This class determins whether the appointment is of a specific archetype by examining.
    # the appointment status, kind, service category, service types, etc.
    class AppointmentsArchetypeService
      # Determines if the appointment cannot be cancelled.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment cannot be cancelled
      def cannot_be_cancelled?(appointment)
        cnp?(appointment) || covid?(appointment) ||
          (cc?(appointment) && booked?(appointment)) || telehealth?(appointment)
      end

      # Checks if the appointment is a request.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is a request, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def request?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:status] == 'proposed'
      end

      # Checks if the appointment is booked.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is booked, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def booked?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:status] == 'booked'
      end

      # Checks if appointment is eligible for receiving an AVS link, i.e.
      # the appointment is booked and in the past
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is eligible, false otherwise
      #
      def avs_applicable?(appt)
        return false if appt.nil? || appt[:status].nil? || appt[:start].nil?

        appt[:status] == 'booked' && appt[:start].to_datetime.past?
      end

      # Determines if the appointment is for community care.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for community care, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def cc?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:kind] == 'cc'
      end

      # Determines if the appointment is for compensation and pension.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for compensation and pension, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def cnp?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_category]).include? 'COMPENSATION & PENSION'
      end

      # Determines if the appointment is a medical appointment.
      #
      # @param appt [Hash] The hash object containing appointment details.
      # @return [Boolean] true if the appointment is a medical appointment, false otherwise.
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def medical?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_category]).include?('REGULAR')
      end

      # Determines if the appointment does not have a service category.
      #
      # @param appt [Hash] The hash object containing appointment details.
      # @return [Boolean] true if the appointment does not have a service category, false otherwise.
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def no_service_cat?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_category]).empty?
      end

      private

      # Determines if the appointment is for covid.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for covid, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def covid?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_types]).include?('covid') || appt[:service_type] == 'covid'
      end

      # Determines if the appointment is for telehealth.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for telehealth, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def telehealth?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:kind] == 'telehealth'
      end

      # Get codes from a list of codeable concepts.
      #
      # @param input [Array<Hash>] An array of codeable concepts.
      # @return [Array<String>] An array of codes.
      #
      def codes(input)
        return [] if input.nil?

        input.flat_map { |codeable_concept| codeable_concept[:coding]&.pluck(:code) }.compact
      end
    end
  end
end
