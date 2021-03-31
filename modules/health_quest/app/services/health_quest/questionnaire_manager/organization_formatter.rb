# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object responsible for formatting organization data into a hash of key/value pairs
    #
    # @!attribute orgs_array
    #   @return [Array]
    # @!attribute facilities
    #   @return [Array]
    class OrganizationFormatter
      attr_reader :orgs_array, :facilities

      ##
      # Builds a HealthQuest::QuestionnaireManager::OrganizationFormatter instance
      #
      # @param orgs_array [Array] an array of `Organization` instances.
      # @param facilities [Array] facilities data to patch missing organization phone numbers.
      # @return [HealthQuest::QuestionnaireManager::OrganizationFormatter] an instance of this class
      #
      def self.build(orgs_array, facilities)
        new(orgs_array, facilities)
      end

      def initialize(orgs_array, facilities)
        @orgs_array = orgs_array
        @facilities = facilities
      end

      ##
      # Builds and returns a hash of organization with IDs for keys; Sets the orgs phone numbers
      # from the `facilities_by_ids` hash
      #
      # @return [Hash]
      #
      def to_h
        orgs_array.each_with_object({}) do |org, accumulator|
          add_phones_to_org(org)

          facility_id = org.resource.identifier.last.value
          accumulator[facility_id] = org
        end
      end

      ##
      # Returns an Organization `FHIR::ClientReply` instance with the `telecom` field
      # populated with `FHIR::ContactPoint` instances based on data from the Facilities API
      # for the given `org` attribute.
      #
      # @param org [FHIR::ClientReply]
      # @return [FHIR::ClientReply]
      #
      def add_phones_to_org(org)
        id = org.resource.identifier.last.value
        phones = facilities_by_ids.dig(id, 'attributes', 'phone')
        telecom = org.resource.telecom

        telecom.clear

        phones.each do |key, val|
          contact = FHIR::ContactPoint.new
          contact.system = key
          contact.value = val

          telecom << contact
        end

        org
      end

      ##
      # Builds and returns a hash of facilities with IDs for keys
      #
      # @return [Hash]
      #
      def facilities_by_ids
        @facilities_by_ids ||=
          facilities.each_with_object({}) do |fac, acc|
            id = fac['id']

            acc[id] = fac
          end
      end
    end
  end
end
