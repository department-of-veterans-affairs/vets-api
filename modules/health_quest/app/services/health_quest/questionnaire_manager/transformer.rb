# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for mixing and blending data for the QuestionnaireManager::Factory
    #
    class Transformer
      USE_CONTEXT_DELIMITER = ','

      ##
      # Builds a HealthQuest::QuestionnaireManager::Transformer instance
      #
      # @return [HealthQuest::QuestionnaireManager::Transformer] an instance of this class
      #
      def self.build
        new
      end

      ##
      # Builds the final aggregated data structure after the PGD and appointment
      # health_quest services are passed in as key/value arguments
      #
      # @return [Hash] a combined hash containing appointment, questionnaire_response,
      # questionnaire and SIP data
      #
      def combine(_opts)
        { data: 'WIP' }
      end

      ##
      # Builds the UseContext string from a list of Appointments
      #
      # @return [String] a context-type-value built using facility and clinic IDs
      #
      def get_use_context(appointments)
        use_context_array =
          appointments.each_with_object([]) do |apt, accumulator|
            item = "venue$#{apt.facility_id}/#{apt.clinic_id}"

            accumulator << item
          end

        use_context_array.join(USE_CONTEXT_DELIMITER)
      end
    end
  end
end
