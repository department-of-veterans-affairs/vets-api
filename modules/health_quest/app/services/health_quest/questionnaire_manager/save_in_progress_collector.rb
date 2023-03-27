# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for setting the status of the save in progress for the questionnaire
    #
    # @!attribute groups
    #   @return [ResponsesGroup]
    class SaveInProgressCollector
      IN_PROGRESS_STATUS = 'in-progress'
      ID_MATCHER = /_([a-zA-Z0-9-]+)\z/i

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
      # Sets the save in progress status in the questionnaire response
      # for the given questionnaire
      #
      # @return [Array] an array of SIP objects for a questionnaire
      #
      def collect
        groups.sip_responses&.each do |sip|
          sip_quest_id = sip.form_id.match(ID_MATCHER)[1]
          questionnaire = groups.appt_questionnaires[sip_quest_id]
          next if questionnaire.blank?

          response_hash = { form_id: sip.form_id, status: IN_PROGRESS_STATUS }

          questionnaire[:questionnaire_response] << response_hash.with_indifferent_access
        end
      end
    end
  end
end
