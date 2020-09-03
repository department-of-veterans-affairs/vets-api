# frozen_string_literal: true

require 'common/client/base'

module Vet360
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.vet360'

    def initialize(user)
      @user = user
    end

    def perform(method, path, body = nil, headers = {})
      log_dates(body)

      Vet360::Stats.increment('total_operations')
      config.base_request_headers.merge(headers)
      response = super(method, path, body, headers)

      response
    end

    def self.breakers_service
      Common::Client::Base.breakers_service
    end

    private

    def log_dates(body)
      parsed_body = JSON.parse(body)

      Raven.extra_context(
        request_dates: parsed_body['bio'].slice('effectiveStartDate', 'effectiveEndDate', 'sourceDate')
      )
    rescue
      nil
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ParsingError # Vet360 sent a non-JSON response
        Raven.extra_context(
          message: error.message,
          url: config.base_path
        )
        raise_backend_exception('VET360_502', self.class)
      when Common::Client::Errors::ClientError
        save_error_details(error)
        raise Common::Exceptions::Forbidden if error.status == 403

        raise_invalid_body(error, self.class) unless error.body.is_a?(Hash)
        code = parse_messages(error)&.first.try(:[], 'code')
        raise_backend_exception("VET360_#{code}", self.class, error) if code.present?
        raise_backend_exception('VET360_502', self.class, error)
      else
        raise error
      end
    end

    def save_error_details(error)
      Raven.extra_context(
        message: error.message,
        url: config.base_path,
        body: error.body
      )

      Raven.tags_context(
        vet360: person_transaction_failure?(error) ? 'failed_vet360_id_initializations' : 'general_client_error'
      )
    end

    def person_transaction_failure?(error)
      person_transaction?(error) && final_failure?(error)
    end

    def person_transaction?(error)
      error&.backtrace&.join(',')&.include? 'get_person_transaction_status'
    end

    def final_failure?(error)
      %w[COMPLETED_FAILURE REJECTED].include? error.body&.dig('status')
    end

    def parse_messages(error)
      messages = error.body&.dig('messages')
      messages&.map { |m| Vet360::Models::Message.build_from(m) }
    end

    def raise_backend_exception(key, source, error = nil)
      report_stats_on(key)
      super
    end

    def raise_invalid_body(error, source)
      Vet360::Stats.increment_exception('VET360_502')

      raise Common::Exceptions::BackendServiceException.new(
        'VET360_502',
        { source: source.to_s },
        502,
        error&.body
      )
    end

    def report_stats_on(exception_key)
      if Vet360::Exceptions::Parser.instance.known?(exception_key)
        Vet360::Stats.increment_exception(exception_key)
      else
        log_message_to_sentry('New Vet360 Exceptions Key', :info, key: exception_key)
      end
    end
  end
end
