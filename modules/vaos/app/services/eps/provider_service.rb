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
                         {}, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Get provider data from EPS
    #
    # @return OpenStruct response from EPS provider endpoint
    #
    def get_provider_service(provider_id:)
      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}",
                         {}, request_headers)

      OpenStruct.new(response.body)
    end

    def get_provider_services_by_ids(provider_ids:)
      query_object_array = provider_ids.map { |id| "id=#{id}" }
      response = perform(:get, "/#{config.base_path}/provider-services",
                         query_object_array, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Get networks from EPS
    #
    # @return OpenStruct response from EPS networks endpoint
    #
    def get_networks
      response = perform(:get, "/#{config.base_path}/networks", {}, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Get drive times from EPS
    #
    # @param destinations [Hash] Hash of UUIDs mapped to lat/long coordinates
    # @param origin [Hash] Hash containing origin lat/long coordinates
    # @return OpenStruct response from EPS drive times endpoint
    #
    def get_drive_times(destinations:, origin:)
      payload = {
        destinations:,
        origin:
      }

      response = perform(:post, "/#{config.base_path}/drive-times", payload, request_headers)

      OpenStruct.new(response.body)
    end

    ##
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

      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", params, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Search for provider services using NPI
    #
    # @param npi [String] NPI number to search for
    #
    # @return OpenStruct response containing the provider service where an individual provider has
    # matching NPI, or nil if not found
    #
    def search_provider_services(npi:)
      query_params = { npi: }
      response = perform(:get, "/#{config.base_path}/provider-services", query_params, request_headers)

      # NPIs are unique, so we expect either an empty array or an array with exactly one matching provider
      response.body[:provider_services]&.first&.then { |provider| OpenStruct.new(provider) }
    end

    private

    def build_search_params(params)
      {
        searchText: params[:search_text],
        appointmentId: params[:appointment_id],
        npi: params[:npi],
        networkId: params[:network_id],
        maxMilesFromNear: params[:max_miles_from_near],
        nearLocation: params[:near_location],
        organizationNames: params[:organization_names],
        specialtyIds: params[:specialty_ids],
        visitModes: params[:visit_modes],
        includeInactive: params[:include_inactive],
        digitalOrNot: params[:digital_or_not],
        isSelfSchedulable: params[:is_self_schedulable],
        nextToken: params[:next_token]
      }.compact
    end
  end
end
