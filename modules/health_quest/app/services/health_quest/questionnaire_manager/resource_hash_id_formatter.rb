# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting Resource data into a hash of key/value pairs
    #
    # @!attribute resource_array
    #   @return [Array]
    class ResourceHashIdFormatter
      attr_reader :resource_array

      ##
      # Builds a HealthQuest::QuestionnaireManager::ResourceHashIdFormatter instance
      #
      # @param resource_array [Array] an array of `<Resource>` instances.
      # @return [HealthQuest::QuestionnaireManager::ResourceHashIdFormatter] an instance of this class
      #
      def self.build(resource_array)
        new(resource_array)
      end

      def initialize(resource_array)
        @resource_array = resource_array
      end

      ##
      # Builds and returns a hash of resources with IDs for keys
      #
      # @return [Hash]
      #
      def to_h
        resource_array.each_with_object({}) do |resource, accumulator|
          resource_id = resource&.resource&.id

          accumulator[resource_id] = resource
        end
      end
    end
  end
end
