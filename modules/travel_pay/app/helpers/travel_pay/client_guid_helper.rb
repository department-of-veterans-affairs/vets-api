# frozen_string_literal: true

module TravelPay
  # Helper class to manage client GUID lookups and validation
  class ClientGuidHelper
    class ClientGuidNotFoundError < StandardError; end

    # Looks up the client number based on the provided client GUID
    # @param client_guid [String] The client GUID from the request header
    # @return [String] The client number for the given GUID
    # @raise [ClientGuidNotFoundError] If the client GUID is not found in settings
    def self.get_client_number(client_guid)
      return client_guid if client_guid.nil?

      client_config = Settings.travel_pay.clients.find { |_, config| config.consumer_guid == client_guid }
      raise ClientGuidNotFoundError, "Client GUID '#{client_guid}' not found in configuration" if client_config.nil?

      client_config[1].client_number
    end
  end
end
