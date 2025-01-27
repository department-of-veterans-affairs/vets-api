# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting Questionnaire data into a hash of array values
    #
    # @!attribute questionnaires_array
    #   @return [Array]
    class QuestionnaireFormatter
      attr_reader :questionnaires_array

      ##
      # Builds a HealthQuest::QuestionnaireManager::QuestionnaireFormatter instance
      #
      # @param questionnaires_array [Array] an array of `Questionnaire` instances.
      # @return [HealthQuest::QuestionnaireManager::QuestionnaireFormatter] an instance of this class
      #
      def self.build(questionnaires_array)
        new(questionnaires_array)
      end

      def initialize(questionnaires_array)
        @questionnaires_array = questionnaires_array
      end

      ##
      # Builds and returns a hash of array values with `facility_id/clinic_id` for keys
      #
      # @return [Hash] a formatted hash of Questionnaire data
      #
      def to_h
        questionnaires_array.each_with_object({}) do |quest, accumulator|
          use_contexts = use_contexts(quest)
          vcc = value_codeable_concepts(use_contexts)
          codes = codes(vcc)

          codes.each do |code|
            accumulator[code] ||= []
            accumulator[code] << quest
          end
        end
      end

      ##
      # Gets an array of useContext objects from a Questionnaire
      #
      # @return [Array] an array of useContexts
      #
      def use_contexts(questionnaire)
        questionnaire.to_hash.dig('resource', 'useContext')
      end

      ##
      # Gets an array of coding objects from a useContext objects
      #
      # @return [Array] an array of `coding` objects
      #
      def value_codeable_concepts(use_contexts)
        use_contexts.map { |uc| uc.dig('valueCodeableConcept', 'coding') }.flatten
      end

      ##
      # Gets an array of code objects from `valueCodeableConcept` objects
      #
      # @return [Array] an array of `code` objects
      #
      def codes(vcc)
        vcc.pluck('code')
      end
    end
  end
end
