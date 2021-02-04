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
      attr_reader :aggregated_data,
                  :patient,
                  :patient_service,
                  :user

      def self.manufacture(user)
        new(user)
      end

      def initialize(user)
        @aggregated_data = default_response
        @user = user
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

      def default_response
        { data: [] }
      end
    end
  end
end
