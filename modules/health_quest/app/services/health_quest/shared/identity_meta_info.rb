# frozen_string_literal: true

module HealthQuest
  module Shared
    module IdentityMetaInfo
      ##
      # The namespace URI for the FHIR::Identifier object
      #
      SYSTEM_ID = 'urn:uuid:2.16.840.1.113883.4.349'
      ##
      # Identity of the terminology system for the FHIR::Identifier object
      #
      CODING_SYSTEM = 'https://pki.dmdc.osd.mil/milconnect'
      ##
      # Operation Resource meta tag for the FHIR::Meta object
      #   VA URI
      META_SYSTEM = 'https://api.va.gov/services/pgd'
      ##
      # Operation Resource meta tag for the FHIR::Meta object
      #   VA identifier
      META_CODE = '66a5960c-68ee-4689-88ae-4c7cccf7ca79'
      ##
      # Operation Resource meta tag for the FHIR::Meta object
      #   VA application identifier
      META_DISPLAY = 'VA GOV CLIPBOARD'

      ##
      # Builds and sets attributes on the FHIR::Identifier object.
      #
      # @return [FHIR::Identifier]
      #
      def set_identifiers
        identifier.tap do |i|
          i.value = identifier_value
          i.system = SYSTEM_ID
          i.type = identifier_type
        end
      end

      ##
      # Build the hash for the Patient objects identifier type.
      #
      # @return [Hash]
      #
      def identifier_type
        codeable_concept.tap do |cc|
          coding = FHIR::Coding.new
          coding.system = CODING_SYSTEM
          coding.code = identifier_code
          coding.userSelected = false

          cc.coding = [coding]
        end
      end

      ##
      # Builds and sets the tag array attribute on the FHIR::Meta object.
      #
      # @return [FHIR::Meta]
      #
      def set_meta
        coding = FHIR::Coding.new
        coding.system = META_SYSTEM
        coding.code = META_CODE
        coding.display = META_DISPLAY

        meta.tag = [coding]
        meta
      end

      ##
      # Method non-implementation warning.
      #
      # @return [NotImplementedError]
      #
      def identifier
        raise NotImplementedError "#{self.class} should have implemented identifier ..."
      end

      ##
      # Method non-implementation warning.
      #
      # @return [NotImplementedError]
      #
      def meta
        raise NotImplementedError "#{self.class} should have implemented meta ..."
      end

      ##
      # Method non-implementation warning.
      #
      # @return [NotImplementedError]
      #
      def identifier_value
        raise NotImplementedError "#{self.class} should have implemented identifier_value ..."
      end

      ##
      # Method non-implementation warning.
      #
      # @return [NotImplementedError]
      #
      def identifier_code
        raise NotImplementedError "#{self.class} should have implemented identifier_code ..."
      end

      ##
      # Method non-implementation warning.
      #
      # @return [NotImplementedError]
      #
      def codeable_concept
        raise NotImplementedError "#{self.class} should have implemented codeable_concept ..."
      end
    end
  end
end
