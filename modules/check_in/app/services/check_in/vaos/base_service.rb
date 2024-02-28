# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module CheckIn
  module VAOS
    class BaseService < Common::Client::Base
      include SentryLogging
      include Common::Client::Concerns::Monitoring

      attr_reader :patient_icn, :token_service

      STATSD_KEY_PREFIX = 'api.check_in.vaos'

      def initialize(patient_icn:)
        @patient_icn = patient_icn
        @token_service = CheckIn::Map::TokenService.build({ patient_icn: })
        super()
      end

      def perform(method, path, params, headers = nil, options = nil)
        super(method, path, params, headers, options)
      end

      def config
        CheckIn::VAOS::Configuration.instance
      end

      def headers
        {
          'Referer' => referrer,
          'X-VAMF-JWT' => token_service.token,
          'X-Request-ID' => RequestStore.store['request_id']
        }
      end

      def referrer
        if Settings.hostname.ends_with?('.gov')
          "https://#{Settings.hostname}".gsub('vets', 'va')
        else
          'https://review-instance.va.gov' # VAMF rejects Referer that is not valid; such as those of review instances
        end
      end
    end
  end
end
