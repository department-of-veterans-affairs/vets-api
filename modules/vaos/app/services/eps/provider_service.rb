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

    # Retrieves available slots for a specific provider.
    #
    # @param provider_id [String] The unique identifier of the provider
    # @param opts [Hash] Optional parameters for the request
    # @option opts [String] :nextToken Token for pagination of results
    # @option opts [String] :appointmentTypeId Required if nextToken is not provided. The type of appointment
    # @option opts [String] :startOnOrAfter Required if nextToken is not provided. Start of the time range
    #   (ISO 8601 format)
    # @option opts [String] :startBefore Required if nextToken is not provided. End of the time range
    #   (ISO 8601 format)
    # @option opts [Hash] Additional optional parameters will be passed through to the request
    #
    # @raise [ArgumentError] If nextToken is not provided and any of appointmentTypeId, startOnOrAfter, or
    #   startBefore are missing
    #
    # @return [OpenStruct] Response containing available slots
    #
    def get_provider_slots(provider_id, opts = {})
      raise ArgumentError, 'provider_id is required and cannot be blank' if provider_id.blank?

      params = if opts[:nextToken]
                 { nextToken: opts[:nextToken] }
               else
                 required_params = %i[appointmentTypeId startOnOrAfter startBefore]
                 missing_params = required_params - opts.keys

                 raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

                 opts
               end

      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", params, headers)
      OpenStruct.new(response.body)
    end
  end
end
