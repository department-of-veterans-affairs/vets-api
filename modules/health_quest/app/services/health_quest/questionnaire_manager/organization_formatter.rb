# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for formatting Resource data into a hash of key/value pairs
    #
    # @!attribute orgs_array
    #   @return [Array]
    class OrganizationFormatter
      attr_reader :orgs_array

      ##
      # Builds a HealthQuest::QuestionnaireManager::OrganizationFormatter instance
      #
      # @param orgs_array [Array] an array of `Organization` instances.
      # @return [HealthQuest::QuestionnaireManager::OrganizationFormatter] an instance of this class
      #
      def self.build(orgs_array)
        new(orgs_array)
      end

      def initialize(orgs_array)
        @orgs_array = orgs_array
      end

      ##
      # Builds and returns a hash of resources with IDs for keys
      #
      # @return [Hash]
      #
      def to_h
        orgs_array.each_with_object({}) do |org, accumulator|
          facility_id = org.resource.identifier.last.value

          accumulator[facility_id] = org
        end
      end
    end
  end
end
