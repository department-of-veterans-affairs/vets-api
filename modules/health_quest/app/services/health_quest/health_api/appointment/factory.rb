# frozen_string_literal: true

module HealthQuest
  module HealthApi
    module Appointment
      ##
      # A service object for isolating dependencies from any implementing service or controller.
      #
      # @!attribute session_service
      #   @return [HealthQuest::Lighthouse::Session]
      # @!attribute user
      #   @return [User]
      # @!attribute map_query
      #   @return [HealthApi::Appointment::MapQuery]
      class Factory
        attr_reader :session_service, :user, :map_query

        ##
        # Builds a HealthApi::Appointment::Factory instance from a given User
        #
        # @param user [User] the currently logged in user.
        # @return [HealthApi::Appointment::Factory] an instance of this class
        #
        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @user = user
          @session_service = HealthQuest::Lighthouse::Session.build(user: user, api: health_api)
          @map_query = HealthApi::Appointment::MapQuery.build(session_service.retrieve)
        end

        private

        def health_api
          Settings.hqva_mobile.lighthouse.health_api
        end
      end
    end
  end
end
