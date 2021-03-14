# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting basic QuestionnaireManager data into a hash
    #
    # @!attribute appointments
    #   @return [Array]
    # @!attribute hashed_organizations
    #   @return [Hash]
    # @!attribute hashed_locations
    #   @return [Hash]
    # @!attribute hashed_questionnaires
    #   @return [Hash]
    class BasicQuestionnaireManagerFormatter
      ID_MATCHER = /([I2\-a-zA-Z0-9]+)\z/i.freeze

      attr_reader :appointments, :hashed_organizations, :hashed_locations, :hashed_questionnaires

      ##
      # Builds a HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter instance
      #
      # @param opts [Hash] a set of options.
      # @return [HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @appointments = opts[:appointments]
        @hashed_organizations = opts[:hashed_organizations]
        @hashed_locations = opts[:hashed_locations]
        @hashed_questionnaires = opts[:hashed_questionnaires]
      end

      ##
      # Builds an array of appointments and their orgs and locations and questionnaires
      # and placeholder questionnaire responses
      #
      # @return [Array]
      #
      def to_a
        appointments.each_with_object([]) do |appt, accumulator|
          location_id = appt_location_id(appt)
          location = hashed_locations[location_id]
          quest_key = location.resource.identifier.last.value
          org_key = location.resource.identifier.first.value
          org = hashed_organizations[org_key]

          next unless hashed_questionnaires.key?(quest_key)

          accumulator << {
            appointment: appt.resource.to_hash,
            organization: org.resource.to_hash,
            location: location.resource.to_hash,
            questionnaire: questions_with_qr(quest_key)
          }.with_indifferent_access
        end
      end

      ##
      # Builds a context_key string from an appointment
      #
      # @return [String] a string representing a facility and clinic
      #
      def appt_location_id(appt)
        reference = appt.resource.participant.first.actor.reference

        reference.match(ID_MATCHER)[1]
      end

      ##
      # Builds an array of questionnaires and an associated empty questionnaire
      # response for each questionnaire for a given appointment
      #
      # @return [Array] an array of questionnaires and place holder questionnaire responses
      #
      def questions_with_qr(key)
        hashed_questionnaires[key].map do |quest|
          { id: quest.resource.id, title: quest.resource.title, questionnaire_response: [] }.with_indifferent_access
        end
      end
    end
  end
end
