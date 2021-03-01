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
      # @!attribute options_builder
      #   @return [Shared::OptionsBuilder]
      class Factory
        attr_reader :session_service, :user, :map_query, :options_builder

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
          @options_builder = Shared::OptionsBuilder
        end

        ##
        # Gets the appointment from it's unique ID
        #
        # @param id [String] a unique string value
        # @return [FHIR::ClientReply]
        #
        def get(id) # rubocop:disable Rails/Delegate
          map_query.get(id)
        end

        ##
        # Gets appointments from a given set of query parameters
        #
        # @param filters [Hash] the set of query options.
        # @return [FHIR::ClientReply] an instance of ClientReply
        #
        def search(filters = {})
          filters.merge!(resource_name)

          with_options = options_builder.manufacture(user, filters).to_hash
          map_query.search(with_options)
        end

        ##
        # Builds the key/value pair for identifying the resource
        #
        # @return [Hash] a key value pair
        #
        def resource_name
          { resource_name: 'appointment' }
        end

        private

        def health_api
          Settings.hqva_mobile.lighthouse.health_api
        end
      end
    end
  end
end
