# frozen_string_literal: true

require 'common/client/configuration/rest'

module Kafka
  module SchemaRegistry
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.kafka_producer.schema_registry_url
      end

      def self.base_request_headers
        super.merge('Content-Type' => 'application/vnd.schemaregistry.v1+json')
      end

      def service_name
        'KafkaSchemaRegistry'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
