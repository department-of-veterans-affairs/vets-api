# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting basic QuestionnaireManager data into a hash
    #
    # @!attribute appointments
    #   @return [Array]
    # @!attribute hashed_questionnaires
    #   @return [Hash]
    class BasicQuestionnaireManagerFormatter
      attr_reader :appointments, :hashed_questionnaires

      ##
      # Builds a HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter instance
      #
      # @param appointments [Array] an array of appointments.
      # @param hashed_questionnaires [Hash] a hash of questionnaires.
      # @return [HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter] an instance of this class
      #
      def self.build(appointments, hashed_questionnaires)
        new(appointments, hashed_questionnaires)
      end

      def initialize(appointments, hashed_questionnaires)
        @appointments = appointments
        @hashed_questionnaires = hashed_questionnaires
      end

      ##
      # Builds an array of appointments and their questionnaires
      # and placeholder questionnaire responses
      #
      # @return [Array] an array of appointments and associated data
      #
      def to_a
        appointments.each_with_object([]) do |appt, accumulator|
          key = context_key(appt)
          next unless hashed_questionnaires.key?(key)

          accumulator << { appointment: appt.to_h, questionnaire: questions_with_qr(key) }
        end
      end

      ##
      # Builds a context_key string from an appointment
      #
      # @return [String] a string representing a facility and clinic
      #
      def context_key(appt)
        "#{appt.facility_id}/#{appt.clinic_id}"
      end

      ##
      # Builds an array of questionnaires and an associated empty questionnaire
      # response for each questionnaire for a given appointment
      #
      # @return [Array] an array of questionnaires and place holder questionnaire responses
      #
      def questions_with_qr(key)
        hashed_questionnaires[key].map do |quest|
          { id: quest.resource.id, title: quest.resource.title, questionnaire_response: {} }
        end
      end
    end
  end
end
