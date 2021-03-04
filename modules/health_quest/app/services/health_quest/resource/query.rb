# frozen_string_literal: true

module HealthQuest
  module Resource
    class Query
      include Lighthouse::FHIRClient
      include Lighthouse::FHIRHeaders

      attr_reader :access_token, :api, :headers, :resource_identifier

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @api = opts[:api]
        @resource_identifier = opts[:resource_identifier]
        @access_token = opts[:session_store].token
        @headers = auth_header
      end

      def search(options)
        client.search(fhir_model, search_options(options))
      end

      def get(id)
        client.read(fhir_model, id)
      end

      def create(data, user)
        headers.merge!(content_type_header)

        questionnaire_response = client_model.manufacture(data, user).prepare
        client.create(questionnaire_response)
      end

      def fhir_model
        klass = 'FHIR' + "/#{resource_identifier}".camelize

        klass.constantize
      end

      def client_model
        "health_quest/resource/client_model/#{resource_identifier}".camelize.constantize
      end

      def search_options(options)
        {
          search: {
            parameters: options
          }
        }
      end

      def api_query_path
        case api
        when 'pgd_api'
          Settings.hqva_mobile.lighthouse.pgd_path
        when 'health_api'
          Settings.hqva_mobile.lighthouse.health_api_path
        end
      end
    end
  end
end
