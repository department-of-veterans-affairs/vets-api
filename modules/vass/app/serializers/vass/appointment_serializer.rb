# frozen_string_literal: true

require 'jsonapi/serializer'

module Vass
  ##
  # JSON:API serializer for Appointment resources.
  #
  # This serializer transforms Vass::Appointment models into JSON:API format
  # following the JSON:API specification (https://jsonapi.org/format/).
  #
  # The serializer handles both booked appointments and available time slots,
  # exposing different attributes based on the appointment state. It normalizes
  # the VASS API's varying field names (startUTC vs timeStartUTC) into a
  # consistent format.
  #
  # @example Serialize a single appointment
  #   appointment = Vass::Appointment.new(...)
  #   Vass::AppointmentSerializer.new(appointment).serializable_hash
  #
  # @example Serialize multiple appointments
  #   appointments = [appointment1, appointment2]
  #   Vass::AppointmentSerializer.new(appointments).serializable_hash
  #
  # @see Vass::Appointment
  # @see https://jsonapi.org/format/ JSON:API Specification
  #
  class AppointmentSerializer
    include JSONAPI::Serializer

    set_id :id
    set_type :appointment

    # Core appointment identifiers
    attributes :appointment_id, :veteran_id

    # Scheduled appointment times (for booked appointments)
    attributes :start_utc, :end_utc

    # Cohort window times
    attributes :cohort_start_utc, :cohort_end_utc

    # Available slot times (for availability responses)
    attributes :time_start_utc, :time_end_utc

    # Appointment metadata
    attributes :selected_agent_skills, :status, :capacity, :agent_nickname, :correlation_id

    ##
    # Computed attribute for effective start time.
    # Returns start_utc for booked appointments, time_start_utc for available slots.
    #
    # @param object [Vass::Appointment] The appointment being serialized
    # @return [String, nil] Effective start time
    #
    attribute :effective_start_utc, &:effective_start_utc

    ##
    # Computed attribute for effective end time.
    # Returns end_utc for booked appointments, time_end_utc for available slots.
    #
    # @param object [Vass::Appointment] The appointment being serialized
    # @return [String, nil] Effective end time
    #
    attribute :effective_end_utc, &:effective_end_utc

    ##
    # Computed attribute for appointment duration in minutes.
    #
    # @param object [Vass::Appointment] The appointment being serialized
    # @return [Integer, nil] Duration in minutes or nil if not calculable
    #
    attribute :duration_minutes, &:duration_minutes

    ##
    # Computed attribute indicating if the appointment is booked.
    #
    # @param object [Vass::Appointment] The appointment being serialized
    # @return [Boolean] true if booked, false otherwise
    #
    attribute :is_booked, &:booked?

    ##
    # Computed attribute indicating if the time slot has available capacity.
    #
    # @param object [Vass::Appointment] The appointment being serialized
    # @return [Boolean] true if capacity is available, false otherwise
    #
    attribute :has_capacity, &:available_capacity?

    ##
    # Computed attribute indicating if the appointment has cohort information.
    #
    # @param object [Vass::Appointment] The appointment being serialized
    # @return [Boolean] true if cohort dates exist, false otherwise
    #
    attribute :has_cohort, &:cohort?
  end
end
