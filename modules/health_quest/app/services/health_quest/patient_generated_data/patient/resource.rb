# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module Patient
      ##
      # An object for generating a FHIR Patient resource for the PGD.
      #
      # @!attribute user
      #   @return [User]
      # @!attribute model
      #   @return [FHIR::DSTU2::Patient]
      # @!attribute identifier
      #   @return [FHIR::DSTU2::Identifier]
      # @!attribute meta
      #   @return [FHIR::DSTU2::Meta]
      class Resource
        # The namespace URI for the FHIR::DSTU2::Identifier object
        SYSTEM_ID = 'urn:uuid:2.16.840.1.113883.4.349'
        # Identity of the terminology system
        CODING_SYSTEM = 'https://pki.dmdc.osd.mil/milconnect'
        # Symbol in syntax defined by the system
        IDENTIFIER_CODE = 'ICN'
        # Operation Resource meta tag
        #   VA URI
        META_SYSTEM = 'https://wiki.mobilehealth.va.gov/display/PGDMS/Client+Provenance+Mapping'
        # Operation Resource meta tag
        #   VA identifier
        META_CODE = 'vagov-a0e116eb-faa1-4703-aafe-1a270128607a'
        # Operation Resource meta tag
        #   VA application identifier
        META_DISPLAY = 'VA GOV CLIPBOARD'
        # Patient resource name use capacity
        NAME_USE = 'official'

        attr_reader :model, :identifier, :meta, :user

        ##
        # Builds a PatientGeneratedData::Patient::Resource instance from a given User
        #
        # @param user [User] the currently logged in user.
        # @return [PatientGeneratedData::Patient::Resource] an instance of this class
        #
        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @model = FHIR::DSTU2::Patient.new
          @user = user
          @identifier = FHIR::DSTU2::Identifier.new
          @meta = FHIR::DSTU2::Meta.new
        end

        ##
        # Builds the FHIR::DSTU2::Patient object for the PGD.
        #
        # @return [FHIR::DSTU2::Patient]
        #
        def prepare
          model.tap do |p|
            p.name = name
            p.identifier = set_identifiers
            p.meta = set_meta
          end
        end

        ##
        # Builds and sets attributes on the FHIR::DSTU2::Identifier object.
        #
        # @return [FHIR::DSTU2::Identifier]
        #
        def set_identifiers
          identifier.tap do |i|
            i.value = user.icn
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
              code: IDENTIFIER_CODE,
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
        # Build the name array for the Patient object.
        #
        # @return [Array]
        #
        def name
          [{
            use: NAME_USE,
            family: [user.last_name],
            given: [user.first_name]
          }]
        end
      end
    end
  end
end
