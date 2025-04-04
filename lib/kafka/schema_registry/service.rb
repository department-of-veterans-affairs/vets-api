# frozen_string_literal: true

require_relative 'configuration'

module Kafka
  module SchemaRegistry
    class Service < Common::Client::Base
      configuration SchemaRegistry::Configuration

      SCHEMA_REGISTRY_PATH_PREFIX = '/ves-event-bus-infra/schema-registry'

      def fetch(id)
        data = request("#{SCHEMA_REGISTRY_PATH_PREFIX}/schemas/ids/#{id}", idempotent: true)
        data.fetch(:schema)
      end

      # List all subjects
      def subjects
        request("#{SCHEMA_REGISTRY_PATH_PREFIX}/subjects", idempotent: true)
      end

      # List all versions for a subject
      def subject_versions(topic)
        validate_topic(topic)
        request("#{SCHEMA_REGISTRY_PATH_PREFIX}/subjects/#{topic}-value/versions", idempotent: true)
      end

      # Get a specific version for a subject
      def subject_version(topic, version = 'latest')
        validate_topic(topic)
        request("#{SCHEMA_REGISTRY_PATH_PREFIX}/subjects/#{topic}-value/versions/#{version}", idempotent: true)
      end

      # Get the subject and version for a schema id
      def schema_subject_versions(schema_id)
        request("#{SCHEMA_REGISTRY_PATH_PREFIX}/schemas/ids/#{schema_id}/versions", idempotent: true)
      end

      # Check if a schema exists. Returns nil if not found.
      def check(topic, schema)
        validate_topic(topic)
        data = request("#{SCHEMA_REGISTRY_PATH_PREFIX}/subjects/#{topic}-value",
                       method: :post,
                       expects: [200, 404],
                       body: { schema: schema.to_s }.to_json,
                       idempotent: true)
        data unless data.key?('error_code')
      end

      # Check if a schema is compatible with the stored version.
      # Returns:
      # - true if compatible
      # - nil if the subject or version does not exist
      # - false if incompatible
      # http://docs.confluent.io/3.1.2/schema-registry/docs/api.html#compatibility
      def compatible?(topic, schema, version = 'latest')
        validate_topic(topic)
        data = request("#{SCHEMA_REGISTRY_PATH_PREFIX}/compatibility/subjects/#{topic}-value/versions/#{version}",
                       method: :post,
                       expects: [200, 404],
                       body: { schema: schema.to_s }.to_json,
                       idempotent: true)
        data.fetch(:is_compatible, false) unless data.key?('error_code')
      end

      # Check for specific schema compatibility issues
      # Returns:
      # - nil if the subject or version does not exist
      # - a list of compatibility issues
      # https://docs.confluent.io/platform/current/schema-registry/develop/api.html#sr-api-compatibility
      def compatibility_issues(topic, schema, version = 'latest')
        validate_topic(topic)
        data = request("#{SCHEMA_REGISTRY_PATH_PREFIX}/compatibility/subjects/#{topic}-value/versions/#{version}",
                       method: :post,
                       expects: [200, 404],
                       body: { schema: schema.to_s }.to_json, query: { verbose: true }, idempotent: true)
        data.fetch(:messages, []) unless data.key?('error_code')
      end

      # Get global config
      def global_config
        request("#{SCHEMA_REGISTRY_PATH_PREFIX}/config", idempotent: true)
      end

      # Get config for subject
      def subject_config(topic)
        validate_topic(topic)
        request("#{SCHEMA_REGISTRY_PATH_PREFIX}/config/#{topic}-value", idempotent: true)
      end

      private

      def request(path, method: :get, **options)
        options = { expects: 200 }.merge!(options)
        response = connection.send(method, path) do |req|
          req.headers = options[:headers] if options[:headers]
        end

        JSON.parse(response.body)
      end

      def validate_topic(topic)
        raise WaterDrop::Errors::MessageInvalidError.new(topic: 'no topic provided') if topic.blank?
      end
    end
  end
end
