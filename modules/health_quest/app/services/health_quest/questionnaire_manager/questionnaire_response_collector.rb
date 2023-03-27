# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for setting the questionnaire response for the questionnaire
    #
    # @!attribute groups
    #   @return [ResponsesGroup]
    class QuestionnaireResponseCollector
      ID_MATCHER = %r{Questionnaire/([a-z0-9-]+)\z}i

      attr_reader :groups

      ##
      # Builds a HealthQuest::QuestionnaireManager::SaveInProgressCollector instance
      #
      # @param groups [ResponsesGroup] SIP and questionnaire responses helper object.
      # @return [HealthQuest::QuestionnaireManager::SaveInProgressCollector] an instance of this class
      #
      def self.build(groups)
        new(groups)
      end

      def initialize(groups)
        @groups = groups
      end

      ##
      # Sets the questionnaire response for the questionnaire
      #
      # @return [Array] an array of questionnaire response objects
      #
      def collect
        groups.qr_responses&.each do |qr|
          quest_id = qr.resource.questionnaire.match(ID_MATCHER)[1]
          questionnaire = groups.appt_questionnaires[quest_id]
          next if questionnaire.blank?

          response_hash = { id: qr.resource.id, status: qr.resource.status, submitted_on: qr.resource.authored }

          questionnaire[:questionnaire_response] << response_hash.with_indifferent_access
        end
      end
    end
  end
end
