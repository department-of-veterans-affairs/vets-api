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
        include PatientGeneratedData::Common::IdentityMetaInfo
        ##
        # Patient resource name use capacity
        #
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

        ##
        # Return the patients ICN.
        #
        # @return [String]
        #
        def identifier_value
          user.icn
        end

        ##
        # Return the patients identifier attribute name.
        #
        # @return [String]
        #
        def identifier_code
          'ICN'
        end
      end
    end
  end
end
