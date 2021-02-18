# frozen_string_literal: true

module HealthQuest
  module HealthApi
    module Patient
      ##
      # A service object for isolating dependencies from any implementing service or controller.
      #
      # @!attribute session_service
      #   @return [HealthQuest::Lighthouse::Session]
      # @!attribute user
      #   @return [User]
      # @!attribute map_query
      #   @return [HealthApi::Patient::MapQuery]
      class Factory
        attr_reader :session_service, :user, :map_query

        ##
        # Builds a HealthApi::Patient::Factory instance from a given User
        #
        # @param user [User] the currently logged in user.
        # @return [HealthApi::Patient::Factory] an instance of this class
        #
        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @user = user
          @session_service = HealthQuest::Lighthouse::Session.build(user)
          @map_query = HealthApi::Patient::MapQuery.build(session_service.retrieve)
        end

        ##
        # Gets patient information from a user's ICN
        #
        # @return [FHIR::Patient::ClientReply] an instance of ClientReply
        #
        def get
          map_query.get(user.icn)
        end

        ##
        # Create a patient resource from the logged in user
        #
        # @return [FHIR::Patient::ClientReply] an instance of ClientReply
        #
        def create
          map_query.create(user)
        end
      end
    end
  end
end
