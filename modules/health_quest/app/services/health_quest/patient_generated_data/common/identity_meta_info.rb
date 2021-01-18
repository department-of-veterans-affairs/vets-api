# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module Common
      module IdentityMetaInfo
        ##
        # The namespace URI for the FHIR::DSTU2::Identifier object
        #
        SYSTEM_ID = 'urn:uuid:2.16.840.1.113883.4.349'
        ##
        # Identity of the terminology system for the FHIR::DSTU2::Identifier object
        #
        CODING_SYSTEM = 'https://pki.dmdc.osd.mil/milconnect'
        ##
        # Operation Resource meta tag for the FHIR::DSTU2::Meta object
        #   VA URI
        META_SYSTEM = 'https://wiki.mobilehealth.va.gov/display/PGDMS/Client+Provenance+Mapping'
        ##
        # Operation Resource meta tag for the FHIR::DSTU2::Meta object
        #   VA identifier
        META_CODE = 'vagov-a0e116eb-faa1-4703-aafe-1a270128607a'
        ##
        # Operation Resource meta tag for the FHIR::DSTU2::Meta object
        #   VA application identifier
        META_DISPLAY = 'VA GOV CLIPBOARD'

        ##
        # Builds and sets attributes on the FHIR::DSTU2::Identifier object.
        #
        # @return [FHIR::DSTU2::Identifier]
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
          {
            coding: [{
              system: CODING_SYSTEM,
              code: identifier_code,
              userSelected: false
            }]
          }
        end

        ##
        # Builds and sets the tag array attribute on the FHIR::DSTU2::Meta object.
        #
        # @return [FHIR::DSTU2::Meta]
        #
        def set_meta
          meta.tap do |m|
            m.tag = [{
              system: META_SYSTEM,
              code: META_CODE,
              display: META_DISPLAY
            }]
          end
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
      end
    end
  end
end
