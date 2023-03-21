# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting QuestionnaireResponse data into a hash with appointment ids for keys
    #
    # @!attribute qr_array
    #   @return [Array]
    class QuestionnaireResponsesFormatter
      ID_MATCHER = /([I2\-a-zA-Z0-9]+)\z/i

      attr_reader :qr_array

      ##
      # Builds a HealthQuest::QuestionnaireManager::QuestionnaireResponsesFormatter instance
      #
      # @param qr_array [Array] an array of `QuestionnaireResponse` instances.
      # @return [HealthQuest::QuestionnaireManager::QuestionnaireResponsesFormatter] an instance of this class
      #
      def self.build(qr_array)
        new(qr_array)
      end

      def initialize(qr_array)
        @qr_array = qr_array
      end

      ##
      # Builds and returns a hash of array values with appointment_ids for keys
      #
      # @return [Hash] a formatted hash of QuestionnaireResponse data
      #
      def to_h
        qr_array.each_with_object({}) do |qr, accumulator|
          ref = reference(qr)
          id = appointment_id(ref)
          next if id.blank?

          accumulator[id] ||= []
          accumulator[id] << qr
        end
      end

      ##
      # Gets the appointment_id from a `QuestionnaireResponse` reference field
      #
      # @return [String, nil] a user's appointment_id
      #
      def appointment_id(ref)
        matched = ref.match(ID_MATCHER)

        matched ? matched[1] : nil
      end

      ##
      # Gets the reference field from a `QuestionnaireResponse` instance
      #
      # @return [String] a reference to a user's appointment
      #
      def reference(qr)
        qr.resource.subject.reference
      end
    end
  end
end
