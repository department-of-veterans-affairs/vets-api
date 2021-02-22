# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    module FHIRClient
      def url
        "#{lighthouse.url}#{api_query_path}"
      end

      def client
        FHIR::Client.new(url).tap do |client|
          client.use_r4
          client.default_json
          client.additional_headers = headers
          client.set_no_auth
          client.use_minimal_preference
        end
      end

      def headers
        raise NotImplementedError "#{self.class} should have implemented headers ..."
      end

      def api_query_path
        raise NotImplementedError "#{self.class} should have implemented api_query_path ..."
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
