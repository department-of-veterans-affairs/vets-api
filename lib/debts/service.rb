# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'get_letters_response'

module Debts
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration Debts::Configuration

    STATSD_KEY_PREFIX = 'api.debts'

    def get_letters(body)
      with_monitoring_and_error_handling do
        GetLettersResponse.new(perform(:post, 'letterdetails/get', body).body)
      end
    end

    private

    def with_monitoring_and_error_handling
      with_monitoring(2) do
        yield
      end
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
        body: error.body
      )
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        handle_client_error(error)
      else
        raise error
      end
    end

    def handle_client_error(error)
      save_error_details(error)

      raise_backend_exception(
        "DEBTS#{error&.status}",
        self.class,
        error
      )
    end
  end
end
