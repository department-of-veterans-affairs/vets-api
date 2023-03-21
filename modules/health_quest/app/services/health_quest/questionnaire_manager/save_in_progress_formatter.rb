# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting SIP data into a hash with appointment ids for keys
    #
    # @!attribute sip_array
    #   @return [Array]
    class SaveInProgressFormatter
      ID_MATCHER = /HC-QSTNR_([I2\-a-zA-Z0-9]+)_/i

      attr_reader :sip_array

      ##
      # Builds a HealthQuest::QuestionnaireManager::SaveInProgressFormatter instance
      #
      # @param sip_array [Array] an array of `InProgressForm` instances.
      # @return [HealthQuest::QuestionnaireManager::SaveInProgressFormatter] an instance of this class
      #
      def self.build(sip_array)
        new(sip_array)
      end

      def initialize(sip_array)
        @sip_array = sip_array
      end

      ##
      # Builds and returns a hash of array values with appointment_ids for keys
      #
      # @return [Hash] a formatted hash of SIP data
      #
      def to_h
        sip_array.each_with_object({}) do |sip, accumulator|
          id = appointment_id(sip)

          accumulator[id] ||= []
          accumulator[id] << sip
        end
      end

      ##
      # Gets the appointment_id from a `InProgressForm` instance
      #
      # @return [String] a user's appointment_id
      #
      def appointment_id(sip)
        sip.form_id.match(ID_MATCHER)[1]
      end
    end
  end
end
