# frozen_string_literal: true

module Debts
  class Service < Common::Client::Base
    configuration Debts::Configuration

    def get_letters(body)
      with_monitoring do
        GetLettersResponse.new(perform(:post, 'letterdetails/get', body).body)
      end
    rescue => e
      handle_error(e)
    end

    private

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

    def handle_client_error(status)
      save_error_details(error)

      raise_backend_exception(
        "DEBTS#{error&.status}", 
        self.class, 
        error
      )
    end
  end
end
