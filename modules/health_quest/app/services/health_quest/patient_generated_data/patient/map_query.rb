# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module Patient
      ##
      # A service object for querying the PGD for Patient resources.
      #
      # @!attribute headers
      #   @return [Hash]
      class MapQuery
        include PatientGeneratedData::FHIRClient

        attr_reader :headers

        ##
        # Builds a PatientGeneratedData::Patient::MapQuery instance from a given hash of headers.
        #
        # @param headers [Hash] the set of headers.
        # @return [PatientGeneratedData::Patient::MapQuery] an instance of this class
        #
        def self.build(headers)
          new(headers)
        end

        def initialize(headers)
          @headers = headers
        end

        ##
        # Gets patient information from an id
        #
        # @param id [String] the logged in user's ICN.
        # @return [FHIR::Patient::ClientReply] an instance of ClientReply
        #
        def get(id)
          client.read(fhir_model, id)
        end

        ##
        # Create a patient resource from the logged in user.
        #
        # @param user [User] the logged in user.
        # @return [FHIR::Patient::ClientReply] an instance of ClientReply
        #
        def create(user)
          patient = Resource.manufacture(user).prepare

          client.create(patient)
        end

        ##
        # Returns the FHIR::Patient class object
        #
        # @return [FHIR::Patient]
        #
        def fhir_model
          FHIR::Patient
        end
      end
    end
  end
end
