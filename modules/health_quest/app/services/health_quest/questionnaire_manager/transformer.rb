# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for mixing and blending data for the QuestionnaireManager::Factory
    #
    # @!attribute appointments
    #   @return [Array]
    # @!attribute locations
    #   @return [Array]
    # @!attribute organizations
    #   @return [Array]
    # @!attribute facilities
    #   @return [Array]
    # @!attribute questionnaires
    #   @return [Array]
    # @!attribute questionnaire_responses
    #   @return [Array]
    # @!attribute save_in_progress
    #   @return [Array]
    # @!attribute hashed_questionnaires
    #   @return [Hash]
    # @!attribute hashed_questionnaire_responses
    #   @return [Hash]
    # @!attribute hashed_save_in_progress
    #   @return [Hash]
    class Transformer
      attr_reader :appointments,
                  :locations,
                  :organizations,
                  :facilities,
                  :questionnaires,
                  :questionnaire_responses,
                  :save_in_progress,
                  :hashed_locations,
                  :hashed_organizations,
                  :hashed_questionnaires,
                  :hashed_questionnaire_responses,
                  :hashed_save_in_progress

      ##
      # Builds a HealthQuest::QuestionnaireManager::Transformer instance
      #
      # @param user [Hash] the set of data to be used to construct the Questionnaire Manager data.
      # @return [HealthQuest::QuestionnaireManager::Transformer] an instance of this class
      #
      def self.manufacture(opts = {})
        new(opts)
      end

      def initialize(opts)
        @appointments = opts[:lighthouse_appointments]
        @locations = opts[:locations]
        @organizations = opts[:organizations]
        @facilities = opts[:facilities]
        @questionnaires = opts[:questionnaires]
        @questionnaire_responses = opts[:questionnaire_responses]
        @save_in_progress = opts[:save_in_progress]
        @hashed_locations = locations_with_id
        @hashed_organizations = organizations_by_facility_ids
        @hashed_questionnaires = questionnaires_with_facility_clinic_id
        @hashed_questionnaire_responses = questionnaire_responses_with_appointment_id
        @hashed_save_in_progress = sip_with_appointment_id
      end

      ##
      # Builds the final aggregated data structure from a set of optimized data structures:
      # `appointments`, `hashed_questionnaires`, `hashed_questionnaire_responses`,
      # and `hashed_save_in_progress`.
      #
      # @return [Hash] a combined hash containing appointment, questionnaire_response,
      # questionnaire and SIP data
      #
      def combine
        questionnaire_manager_data =
          appointments_with_questionnaires.each_with_object([]) do |base_structure, accumulator|
            groups = get_groups(base_structure)

            set_responses_for_base_structure(groups)
            accumulator << base_structure
          end

        { data: questionnaire_manager_data }
      end

      ##
      # Builds the basic questionnaire manager hash data structure
      #
      # @return [Hash] the base data to return if responses are empty
      #
      def base_data
        { data: appointments_with_questionnaires }
      end

      ##
      # Builds the array of items for the basic questionnaire manager data structure
      #
      # @return [Array] a list of basic hash structures
      #
      def appointments_with_questionnaires
        @appointments_with_questionnaires ||=
          BasicQuestionnaireManagerFormatter.build(
            appointments:,
            hashed_organizations:,
            hashed_locations:,
            hashed_questionnaires:
          ).to_a
      end

      ##
      # Builds the ResponsesGroup object which lets us manage response objects
      # necessary for building the questionnaire manager data structure
      #
      # @return [ResponsesGroup] a helper object for organizing responses
      #
      def get_groups(quest)
        ResponsesGroup.build(quest, hashed_questionnaire_responses, hashed_save_in_progress)
      end

      ##
      # Sets the questionnaire response and sip data for a given questionnaire
      #
      # @return [QuestionnaireResponseCollector, SaveInProgressCollector] the group classes
      #
      def set_responses_for_base_structure(groups)
        [QuestionnaireResponseCollector, SaveInProgressCollector].each { |col| col.build(groups).collect }
      end

      ##
      # Builds the save in progress data hash with appointment_id as keys
      #
      # @return [Hash] a hash of SIP key/values
      #
      def sip_with_appointment_id
        SaveInProgressFormatter.build(save_in_progress).to_h
      end

      ##
      # Builds the questionnaire responses data hash with appointment_id as keys
      #
      # @return [Hash] a hash of questionnaire response key/values
      #
      def questionnaire_responses_with_appointment_id
        QuestionnaireResponsesFormatter.build(questionnaire_responses).to_h
      end

      ##
      # Builds the questionnaire data hash with facility plus clinic ids as keys
      #
      # @return [Hash] a hash of questionnaire key/values
      #
      def questionnaires_with_facility_clinic_id
        QuestionnaireFormatter.build(questionnaires).to_h
      end

      ##
      # Builds the location hash with ids as keys
      #
      # @return [Hash] a hash of locations
      #
      def locations_with_id
        ResourceHashIdFormatter.build(locations).to_h
      end

      ##
      # Builds the organization hash with facility ids as keys
      #
      # @return [Hash] a hash of organizations
      #
      def organizations_by_facility_ids
        OrganizationFormatter.build(organizations, facilities).to_h
      end
    end
  end
end
