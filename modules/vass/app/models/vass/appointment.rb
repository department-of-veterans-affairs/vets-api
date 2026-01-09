# frozen_string_literal: true

require 'common/models/resource'

module Vass
  ##
  # Appointment model representing a veteran's scheduled appointment or available time slot.
  #
  # This model handles appointment data from the VASS API, including scheduled times,
  # cohort information, and appointment metadata. It uses Dry::Struct for type-safe
  # attribute definitions and validations.
  #
  # @!attribute id
  #   @return [String] Unique appointment identifier
  # @!attribute appointment_id
  #   @return [String] Appointment ID in VASS system
  # @!attribute veteran_id
  #   @return [String] Veteran ID (UUID)
  # @!attribute start_utc
  #   @return [String, nil] Appointment start time (UTC ISO8601 format) - uses 'startUTC' from API
  # @!attribute end_utc
  #   @return [String, nil] Appointment end time (UTC ISO8601 format) - uses 'endUTC' from API
  # @!attribute cohort_start_utc
  #   @return [String, nil] Cohort window start time (UTC ISO8601 format)
  # @!attribute cohort_end_utc
  #   @return [String, nil] Cohort window end time (UTC ISO8601 format)
  # @!attribute time_start_utc
  #   @return [String, nil] Available slot start time (UTC ISO8601 format) - uses 'timeStartUTC' from API
  # @!attribute time_end_utc
  #   @return [String, nil] Available slot end time (UTC ISO8601 format) - uses 'timeEndUTC' from API
  # @!attribute selected_agent_skills
  #   @return [Array<String>, nil] Selected agent skill IDs for the appointment
  # @!attribute status
  #   @return [String, nil] Appointment status (e.g., 'booked', 'available', 'cancelled')
  # @!attribute capacity
  #   @return [Integer, nil] Available capacity for the time slot
  # @!attribute agent_nickname
  #   @return [String, nil] Agent nickname/name for booked appointments
  # @!attribute correlation_id
  #   @return [String, nil] Correlation ID for request tracing
  #
  # @example Create a booked appointment
  #   appointment = Vass::Appointment.new(
  #     id: 'appt-123',
  #     appointment_id: 'appt-123',
  #     veteran_id: 'vet-456',
  #     start_utc: '2026-01-15T14:00:00Z',
  #     end_utc: '2026-01-15T14:30:00Z',
  #     cohort_start_utc: '2026-01-01T00:00:00Z',
  #     cohort_end_utc: '2026-01-31T23:59:59Z',
  #     selected_agent_skills: ['skill-1', 'skill-2'],
  #     agent_nickname: 'Dr. Smith',
  #     status: 'booked'
  #   )
  #
  # @example Create an available time slot
  #   appointment = Vass::Appointment.new(
  #     id: 'slot-789',
  #     time_start_utc: '2026-01-15T14:00:00Z',
  #     time_end_utc: '2026-01-15T14:30:00Z',
  #     capacity: 5,
  #     status: 'available'
  #   )
  #
  class Appointment < Common::Resource
    # Status types for appointments
    STATUS_TYPE = Types::String.enum(
      'booked',
      'available',
      'cancelled',
      'pending'
    )

    attribute :id, Types::String
    attribute? :appointment_id, Types::String.optional
    attribute? :veteran_id, Types::String.optional
    attribute? :start_utc, Types::String.optional
    attribute? :end_utc, Types::String.optional
    attribute? :cohort_start_utc, Types::String.optional
    attribute? :cohort_end_utc, Types::String.optional
    attribute? :time_start_utc, Types::String.optional
    attribute? :time_end_utc, Types::String.optional
    attribute? :selected_agent_skills, Types::Array.of(Types::String).optional
    attribute? :status, STATUS_TYPE.optional
    attribute? :capacity, Types::Integer.optional
    attribute? :agent_nickname, Types::String.optional
    attribute? :correlation_id, Types::String.optional

    ##
    # Validates that the appointment has required fields for a booked appointment.
    #
    # @return [Boolean] true if valid, false otherwise
    #
    def valid_booked_appointment?
      appointment_id.present? &&
        veteran_id.present? &&
        start_utc.present? && end_utc.present?
    end

    ##
    # Validates that the time slot has required fields for an available slot.
    #
    # @return [Boolean] true if valid, false otherwise
    #
    def valid_time_slot?
      (time_start_utc.present? && time_end_utc.present?) ||
        (start_utc.present? && end_utc.present?)
    end

    ##
    # Checks if the appointment is within a cohort window.
    #
    # @return [Boolean] true if cohort dates are present
    #
    def cohort?
      cohort_start_utc.present? && cohort_end_utc.present?
    end

    ##
    # Checks if the appointment has selected agent skills.
    #
    # @return [Boolean] true if skills are present
    #
    def selected_skills?
      selected_agent_skills.present? && !selected_agent_skills.empty?
    end

    ##
    # Checks if the appointment is booked (has actual start/end times).
    #
    # @return [Boolean] true if appointment has start and end times
    #
    def booked?
      start_utc.present? && end_utc.present?
    end

    ##
    # Checks if the time slot has available capacity.
    #
    # @return [Boolean] true if capacity is present and greater than 0
    #
    def available_capacity?
      capacity.present? && capacity.positive?
    end

    ##
    # Gets the effective start time (prefers start_utc, falls back to time_start_utc).
    #
    # @return [String, nil] Start time string
    #
    def effective_start_utc
      start_utc || time_start_utc
    end

    ##
    # Gets the effective end time (prefers end_utc, falls back to time_end_utc).
    #
    # @return [String, nil] End time string
    #
    def effective_end_utc
      end_utc || time_end_utc
    end

    ##
    # Parses effective start time to a Time object.
    #
    # @return [Time, nil] Parsed time or nil if invalid
    #
    def start_time
      Time.zone.parse(effective_start_utc) if effective_start_utc.present?
    rescue ArgumentError
      nil
    end

    ##
    # Parses effective end time to a Time object.
    #
    # @return [Time, nil] Parsed time or nil if invalid
    #
    def end_time
      Time.zone.parse(effective_end_utc) if effective_end_utc.present?
    rescue ArgumentError
      nil
    end

    ##
    # Parses cohort_start_utc to a Time object.
    #
    # @return [Time, nil] Parsed time or nil if invalid
    #
    def cohort_start_time
      Time.zone.parse(cohort_start_utc) if cohort_start_utc.present?
    rescue ArgumentError
      nil
    end

    ##
    # Parses cohort_end_utc to a Time object.
    #
    # @return [Time, nil] Parsed time or nil if invalid
    #
    def cohort_end_time
      Time.zone.parse(cohort_end_utc) if cohort_end_utc.present?
    rescue ArgumentError
      nil
    end

    ##
    # Calculates the duration of the appointment in minutes.
    #
    # @return [Integer, nil] Duration in minutes or nil if times are invalid
    #
    def duration_minutes
      return nil unless start_time && end_time

      ((end_time - start_time) / 60).to_i
    end
  end
end
