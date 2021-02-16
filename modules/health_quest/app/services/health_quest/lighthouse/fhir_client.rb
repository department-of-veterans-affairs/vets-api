# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    module FHIRClient
      ##
      # Returns the full lighthouse URL for the request
      #
      # @return [String]
      #
      def url
        "#{lighthouse.url}#{lighthouse_api_path}"
      end

      ##
      # Returns an instance of the client that is
      # used to communicate with the Lighthouse service
      # and is used to GET and POST FHIR resources to it.
      #
      # @return [FHIR::Client]
      #
      def client
        FHIR::Client.new(url).tap do |client|
          client.use_r4
          client.default_json
          client.additional_headers = headers
          client.set_no_auth
          client.use_minimal_preference
        end
      end

      ##
      # Raises an error if the class being included in
      # does not implement the `headers` method
      #
      # @return [NotImplementedError]
      #
      def headers
        raise NotImplementedError "#{self.class} should have implemented headers ..."
      end

      ##
      # Raises an error if the class being included in
      # does not implement the `lighthouse_api_path` method
      #
      # @return [NotImplementedError]
      #
      def lighthouse_api_path
        raise NotImplementedError "#{self.class} should have implemented lighthouse_api_path ..."
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
