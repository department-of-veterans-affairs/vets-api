# frozen_string_literal: true

require 'inherited_proofing/mhv/configuration'

module InheritedProofing
  module MHV
    class Service
      def self.get_correlation_data(icn)
        ConfigMethods.new.correlation_id_api_request(icn)
      end

      def self.get_verification_data(correlation_id)
        ConfigMethods.new.verification_info_api_request(correlation_id)
      end

      class ConfigMethods < Common::Client::Base
        configuration InheritedProofing::MHV::Configuration

        def correlation_id_url(icn)
          "#{config.valid_id_url}/#{icn}"
        end

        def verification_info_url(correlation_id)
          "#{config.vacct_info_url}/#{correlation_id}"
        end

        def headers
          { 'appToken' => config.app_token, 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        end

        def correlation_id_api_request(icn)
          response = perform(:get, correlation_id_url(icn), nil, headers)
          JSON.parse(response.body)
        rescue Common::Client::Errors::ClientError
          {}
        end

        def verification_info_api_request(correlation_id)
          response = perform(:get, verification_info_url(correlation_id), nil, headers)
          JSON.parse(response.body)
        rescue Common::Client::Errors::ClientError
          {}
        end
      end
    end
  end
end
