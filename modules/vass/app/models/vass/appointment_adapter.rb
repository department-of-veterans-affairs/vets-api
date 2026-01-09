# frozen_string_literal: true

module Vass
  ##
  # Transforms VASS API responses to Appointment models.
  #
  # This adapter handles the VASS API's inconsistent field naming conventions:
  # - Booked appointments use: startUTC, endUTC (capital UTC)
  # - Available slots use: timeStartUTC, timeEndUTC (capital UTC)
  # - Cohort windows use: cohortStartUtc, cohortEndUtc (mixed case)
  #
  # @example Transform single appointment
  #   api_data = { 'appointmentId' => 'appt-123', 'startUTC' => '2026-01-07T10:00:00Z', ... }
  #   appointment = Vass::AppointmentAdapter.from_api(api_data)
  #
  # @example Transform collection
  #   api_appointments = [{ 'appointmentId' => 'appt-1', ... }, { 'appointmentId' => 'appt-2', ... }]
  #   appointments = Vass::AppointmentAdapter.from_api_collection(api_appointments)
  #
  class AppointmentAdapter
    # Maps VASS API appointment statuses to model status values
    STATUS_MAP = {
      'Scheduled' => 'booked',
      'Available' => 'available',
      'Cancelled' => 'cancelled'
    }.freeze

    ##
    # Transforms a single appointment from VASS API format to Appointment model.
    #
    # @param data [Hash] VASS API appointment data
    # @return [Vass::Appointment, nil] Transformed appointment model or nil if data is blank
    #
    def self.from_api(data)
      return nil if data.blank?

      Vass::Appointment.new(
        id: data['appointmentId'] || SecureRandom.uuid,
        appointment_id: data['appointmentId'],
        veteran_id: data['veteranId'],
        start_utc: data['startUTC'],
        end_utc: data['endUTC'],
        cohort_start_utc: data['cohortStartUtc'],
        cohort_end_utc: data['cohortEndUtc'],
        time_start_utc: data['timeStartUTC'],
        time_end_utc: data['timeEndUTC'],
        selected_agent_skills: data['selectedAgentSkills'],
        capacity: data['capacity'],
        agent_nickname: data['agentNickname'],
        correlation_id: data['correlationId'],
        status: map_status(data['appointmentStatus'])
      )
    end

    ##
    # Transforms an array of appointments from VASS API format.
    #
    # @param appointments [Array<Hash>] Array of VASS API appointment data
    # @return [Array<Vass::Appointment>] Array of transformed appointment models
    #
    def self.from_api_collection(appointments)
      return [] if appointments.blank?

      appointments.map { |data| from_api(data) }.compact
    end

    ##
    # Maps VASS API status string to model status enum value.
    #
    # @param api_status [String, nil] VASS API status string
    # @return [String, nil] Model status value or nil
    #
    def self.map_status(api_status)
      return nil if api_status.blank?

      STATUS_MAP[api_status] || api_status.downcase
    end
  end
end
