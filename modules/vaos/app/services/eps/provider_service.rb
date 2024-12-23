# frozen_string_literal: true

module Eps
  class ProviderService < BaseService
    ##
    # Get providers data from EPS
    #
    # @return OpenStruct response from EPS providers endpoint
    #
    def get_provider_services
      response = perform(:get, "/#{config.base_path}/provider-services",
                         {}, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Get provider data from EPS
    #
    # @return OpenStruct response from EPS provider endpoint
    #
    def get_provider_service(provider_id:)
      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}",
                         {}, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Get networks from EPS
    #
    # @return OpenStruct response from EPS networks endpoint
    #
    def get_networks
      response = perform(:get, "/#{config.base_path}/networks", {}, headers)

      OpenStruct.new(response.body)
    end

    ##
    # Get drive times from EPS
    #
    # @return OpenStruct response from EPS drive times endpoint
    #
    def get_drive_times(latitude, longitude)

      # Latitude and longitude from provider data passed in and used here
      destinations = {
        "12345-abcdef": {
          latitude: latitude,
          longitude: longitude
        }
      }

      origin: {
        # TODO: verify user object attributes (ie, is this where we get origin lat/long from)
        latitude: user.latitude,
        longitude: user.longitude
      }

      response = perform(:get, "/#{config.base_path}/drive-times",
                         { destinations: destinations, origin: origin }, headers)
      OpenStruct.new(response.body)
    end
  end
end
