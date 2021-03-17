# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object which helps reduce clutter in the transformer.rb class by
    # collection SIP and QuestionnaireResponses by a given appointment
    #
    # @!attribute base_qm
    #   @return [Hash]
    # @!attribute hashed_qr
    #   @return [Hash]
    # @!attribute hashed_sip
    #   @return [Hash]
    class ResponsesGroup
      attr_reader :base_qm, :hashed_qr, :hashed_sip

      ##
      # Builds a HealthQuest::QuestionnaireManager::ResponsesGroup instance
      #
      # @param base_qm [Hash] base questionnaire manager data.
      # @param hashed_qr [Hash] a hash of questionnaire responses.
      # @param hashed_sip [Hash] a hash of SIP.
      # @return [HealthQuest::QuestionnaireManager::ResponsesGroup] an instance of this class
      #
      def self.build(base_qm, hashed_qr, hashed_sip)
        new(base_qm, hashed_qr, hashed_sip)
      end

      def initialize(base_qm, hashed_qr, hashed_sip)
        @base_qm = base_qm
        @hashed_qr = hashed_qr
        @hashed_sip = hashed_sip
      end

      ##
      # Returns a boolean based on whether sip and questionnaire responses
      # data are present.
      #
      # @return [Boolean] true if both responses present otherwise false
      #
      def empty?
        qr_responses.blank? && sip_responses.blank?
      end

      ##
      # Returns a hash of questionnaires by a unique questionnaire id
      # for a given appointment in the basic questionnaire manager data structure.
      #
      # @return [Hash] a hash of questionnaires for the appointment
      #
      def appt_questionnaires
        base_qm[:questionnaire].each_with_object({}) do |quest, acc|
          questionnaire_id = quest['id']
          acc[questionnaire_id] = quest
        end
      end

      ##
      # Returns a list of questionnaire responses for an appointment
      #
      # @return [Array] an array of QuestionnaireResponses
      #
      def qr_responses
        hashed_qr[appt_id]
      end

      ##
      # Returns a list of SIP objects for an appointment
      #
      # @return [Array] an array of InProgressForm objects
      #
      def sip_responses
        hashed_sip[appt_id]
      end

      ##
      # Returns an appointment id string.
      #
      # @return [String] an appointments id
      #
      def appt_id
        @appt_id ||= base_qm.dig(:appointment, 'id')
      end
    end
  end
end
