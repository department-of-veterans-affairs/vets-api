# frozen_string_literal: true

module HealthQuest
  module FHIR
    module ClientModel
      ##
      # An object for generating a FHIR Patient data for the PGD.
      #
      # @!attribute user
      #   @return [User]
      # @!attribute model
      #   @return [FHIR::Patient]
      # @!attribute identifier
      #   @return [FHIR::Identifier]
      # @!attribute meta
      #   @return [FHIR::Meta]
      class Patient
        include Shared::IdentityMetaInfo
        ##
        # Patient resource name use capacity
        #
        NAME_USE = 'official'

        attr_reader :data, :model, :identifier, :meta, :user

        ##
        # Builds a HealthApi::FHIR::ClientModel::Patient instance from a given User
        #
        # @param user [User] the currently logged in user.
        # @return [HealthApi::FHIR::ClientModel::Patient] an instance of this class
        #
        def self.manufacture(data, user)
          new(data, user)
        end

        def initialize(data, user)
          @data = data || {}
          @model = ::FHIR::Patient.new
          @user = user
          @identifier = ::FHIR::Identifier.new
          @meta = ::FHIR::Meta.new
        end

        ##
        # Builds the FHIR::Patient object for the Health API.
        #
        # @return [FHIR::Patient]
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
