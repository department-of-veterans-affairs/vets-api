# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/exceptions'

module CovidVaccine
  module V0
    class VetextService < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include SentryLogging

      STATSD_KEY_PREFIX = 'api.covid_vaccine.vetext'

      def put_vaccine_registry(vaccine_registry_attributes)
        with_monitoring do
          response = perform(:put, url, vaccine_registry_attributes, headers)
          # test success
          # test failures
          response.body
        end
      end

      # Supported methods that do not need to be exposed to users
      # def get_vaccine_registry_by_sid
      # end
      #
      # def get_vaccine_registry_by_icn
      # end
      #
      # def get_vaccine_registries_by_station
      # end

      private

      def url
        'api/vetext/pub/covid/vaccine/registry'
      end

      def headers
        {
          'Authorization' => "Basic #{Settings.vetext.token}",
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'Referer' => referrer
        }
      end

      def config
        CovidVaccine::V0::VetextConfiguration.instance
      end

      # Set the referrer (Referer header) to distinguish review instance, staging, etc from logs
      def referrer
        if Settings.hostname.ends_with?('.gov')
          "https://#{Settings.hostname}"
        else
          'https://review-instance.va.gov'
        end
      end
    end
  end
end
