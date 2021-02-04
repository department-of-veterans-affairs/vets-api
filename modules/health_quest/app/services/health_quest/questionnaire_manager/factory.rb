# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # A service object for isolating dependencies from the questionnaire_manager controller.
    # An aggregator which collects and combines data from the health_quest services, those which
    # interact with appointments and patient generated data in particular
    #
    # @!attribute aggregated_data
    #   @return [Hash]
    # @!attribute patient
    #   @return [FHIR::Patient]
    # @!attribute patient_service
    #   @return [PatientGeneratedData::Patient::Factory]
    # @!attribute user
    #   @return [User]
    class Factory
      attr_reader :appointments,
                  :aggregated_data,
                  :patient,
                  :appointment_service,
                  :patient_service,
                  :user

      def self.manufacture(user)
        new(user)
      end

      def initialize(user)
        @aggregated_data = default_response
        @user = user
        @appointment_service = AppointmentService.new(user)
        @patient_service = PatientGeneratedData::Patient::Factory.manufacture(user)
      end

      ##
      # Interacts with and invokes functionality on the PGD and appointment health_quest services.
      # Invokes the `compose` method in the end to stitch all the data together for the controller
      #
      # @return [Hash] an aggregated hash
      #
      def all
        @patient = get_patient.resource
        return default_response if patient.blank?

        @appointments = get_appointments[:data]
        return default_response if appointments.blank?

        compose
      end

      ##
      # Gets a patient resource from the PGD
      #
      # @return [FHIR::Patient::ClientReply] an instance of ClientReply
      #
      def get_patient
        @get_patient ||= patient_service.get
      end

      ##
      # Gets a patients appointments by a default date range
      #
      # @return [Hash] a hash containing appointment data and meta data
      #
      def get_appointments
        @get_appointments ||= appointment_service.get_appointments(three_months_ago, one_year_from_now)
      end

      ##
      # Builds the final aggregated data structure after the PGD and appointment
      # health_quest services are called
      #
      # @return [Hash] a combined hash containing appointment, questionnaire_response,
      # questionnaire and SIP data
      #
      def compose
        { data: 'WIP' }
      end

      private

      def three_months_ago
        3.months.ago.in_time_zone
      end

      def one_year_from_now
        1.year.from_now.in_time_zone
      end

      def default_response
        { data: [] }
      end
    end
  end
end
