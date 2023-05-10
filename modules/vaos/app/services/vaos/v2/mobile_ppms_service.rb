# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobilePPMSService < VAOS::SessionService
      def config
        VAOS::PPMSConfiguration.instance
      end

      # Retrieve a provider with a specified ID.
      #
      # provider_id - The NPI,  of the provider to retrieve.
      #
      # Returns a new OpenStruct object that contains the provider data.
      def get_provider(provider_id)
        params = {}
        with_monitoring do
          response = perform(:get, providers_url_with_id(provider_id), params, headers)
          OpenStruct.new(response[:body])
        end
      end

      # Retrieve a cached provider with a specified ID. If the provider is not cached, fetch it and store it in
      #  cache with an expiration time of 12 hours.
      #
      # provider_id - The NPI of the provider to retrieve.
      #
      # Returns the cached OpenStruct object that contains the provider data
      # or fetches and returns the OpenStruct provider data from the backend service if not already cached.
      #
      # Note: If changing the cached object from OpenStruct to something more complex, reconsider the
      # cache strategy to something like caching the raw JSON response.
      def get_provider_with_cache(provider_id)
        Rails.cache.fetch("vaos_ppms_provider_#{provider_id}", expires_in: 12.hours) do
          get_provider(provider_id)
        end
      end

      private

      def providers_url_with_id(id)
        "/ppms/v1/providers/#{id}"
      end
    end
  end
end
