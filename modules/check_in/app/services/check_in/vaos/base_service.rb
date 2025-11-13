# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'vets/shared_logging'

module CheckIn
  module VAOS
    class BaseService < Common::Client::Base
      include Vets::SharedLogging
      include Common::Client::Concerns::Monitoring

      attr_reader :check_in_session, :patient_icn

      STATSD_KEY_PREFIX = 'api.check_in.vaos'

      ##
      # Builds a Service instance
      #
      # @param opts [Hash] options to create the object
      #
      # @return [Service] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @check_in_session = opts[:check_in_session]
        @patient_icn = ::V2::Lorota::RedisClient.build.icn(uuid: check_in_session.uuid)

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

      def token_service
        @token_service ||= Map::TokenService.build(patient_icn:)
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
