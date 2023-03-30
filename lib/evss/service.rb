# frozen_string_literal: true

require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    attr_reader :transaction_id

    include Common::Client::Concerns::Monitoring
    STATSD_KEY_PREFIX = 'api.evss'

    def initialize(user = nil, auth_headers = nil)
      @user = user
      if auth_headers.nil?
        @headers = EVSS::AuthHeaders.new(user)
        @transaction_id = @headers.transaction_id
      else
        @headers = auth_headers
        @transaction_id = auth_headers['va_eauth_service_transaction_id']
      end
    end

    def perform(method, path, body = nil, headers = {}, options = {})
      merged_headers = @headers.to_h.merge(headers)
      super(method, path, body, merged_headers, options)
    end

    def headers
      { 'Content-Type' => 'application/json' }
    end

    def self.service_is_up?
      last_evss_claims_outage = Breakers::Outage.find_latest(service: EVSS::ClaimsService.breakers_service)
      evss_claims_up = last_evss_claims_outage.blank? || last_evss_claims_outage.end_time.present?

      last_evss_common_outage = Breakers::Outage.find_latest(service: EVSS::CommonService.breakers_service)
      evss_common_up = last_evss_common_outage.blank? || last_evss_common_outage.end_time.present?
      evss_claims_up && evss_common_up
    end

    private

    def with_monitoring_and_error_handling(&)
      with_monitoring(2, &)
    rescue => e
      handle_error(e)
    end

    def save_error_details(error)
      Raven.tags_context(
        external_service: self.class.to_s.underscore
      )

      Raven.extra_context(
        url: config.base_path,
        message: error.message,
        body: error.body,
        transaction_id: @transaction_id
      )
    end

    def handle_error(error)
      Raven.extra_context(
        message: error.message,
        url: config.base_path,
        transaction_id: @transaction_id
      )

      case error
      when Faraday::ParsingError
        raise_backend_exception('EVSS502', self.class)
      when Common::Client::Errors::ClientError
        Raven.extra_context(body: error.body)
        raise Common::Exceptions::Forbidden if error.status == 403

        raise_backend_exception('EVSS400', self.class, error) if error.status == 400
        raise_backend_exception('EVSS502', self.class, error)
      else
        raise error
      end
    end
  end
end
