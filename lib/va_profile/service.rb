# frozen_string_literal: true

require 'common/client/base'
require 'common/client/errors'
require 'common/exceptions/backend_service_exception'
require 'common/exceptions/forbidden'
require_relative 'exceptions/parser'
require_relative 'models/message'
require_relative 'stats'

module VAProfile
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = VAProfile::Stats::STATSD_KEY_PREFIX

    def initialize(user)
      @user = user
    end

    def perform(method, path, body = nil, headers = {})
      log_dates(body)

      VAProfile::Stats.increment('total_operations')
      config.base_request_headers.merge(headers)
      super(method, path, body, headers)
    end

    def self.breakers_service
      Common::Client::Base.breakers_service
    end

    private

    def log_dates(body)
      parsed_body = JSON.parse(body)

      Sentry.set_extras(
        request_dates: parsed_body['bio'].slice('effectiveStartDate', 'effectiveEndDate', 'sourceDate')
      )
    rescue
      nil
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ParsingError # VAProfile sent a non-JSON response
        Sentry.set_extras(
          message: error.message,
          url: config.base_path
        )
        raise_backend_exception('VET360_502', self.class)
      when Common::Client::Errors::ClientError
        save_error_details(error)
        raise Common::Exceptions::Forbidden if error.status == 403

        raise_invalid_body(error, self.class) unless error.body.is_a?(Hash)
        code = parse_messages(error)&.first&.code
        raise_backend_exception("VET360_#{code}", self.class, error) if code.present?
        raise_backend_exception('VET360_502', self.class, error)
      else
        raise error
      end
    end

    def save_error_details(error)
      Sentry.set_extras(
        message: error.message,
        url: config.base_path,
        body: error.body
      )

      Sentry.set_tags(
        va_profile: person_transaction_failure?(error) ? 'failed_vet360_id_initializations' : 'general_client_error'
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
      messages&.map { |m| VAProfile::Models::Message.build_from(m) }
    end

    def raise_backend_exception(key, source, error = nil)
      report_stats_on(key)
      super
    end

    def raise_invalid_body(error, source)
      VAProfile::Stats.increment_exception('VET360_502')

      raise Common::Exceptions::BackendServiceException.new(
        'VET360_502',
        { source: source.to_s },
        502,
        error&.body
      )
    end

    def report_stats_on(exception_key)
      if VAProfile::Exceptions::Parser.instance.known?(exception_key)
        VAProfile::Stats.increment_exception(exception_key)
      else
        log_message_to_sentry('New VAProfile Exceptions Key', :info, key: exception_key)
      end
    end
  end
end
