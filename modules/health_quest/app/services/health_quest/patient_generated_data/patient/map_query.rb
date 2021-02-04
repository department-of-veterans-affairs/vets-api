# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module Patient
      ##
      # A service object for querying the PGD for Patient resources.
      #
      # @!attribute access_token
      #   @return [String]
      # @!attribute headers
      #   @return [Hash]
      class MapQuery
        include PatientGeneratedData::FHIRClient
        include PatientGeneratedData::FHIRHeaders

        attr_reader :access_token, :headers

        ##
        # Builds a PatientGeneratedData::Patient::MapQuery instance from a redis session.
        #
        # @param session_store [HealthQuest::SessionStore] the users redis session.
        # @return [PatientGeneratedData::Patient::MapQuery] an instance of this class
        #
        def self.build(session_store)
          new(session_store)
        end

        def initialize(session_store)
          @access_token = session_store.token
          @headers = auth_header
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
          headers.merge!(content_type_header)

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
