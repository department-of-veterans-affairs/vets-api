# frozen_string_literal: true

module Debts
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration Debts::Configuration

    STATSD_KEY_PREFIX = 'api.debts'

    def get_debts(body)
      with_monitoring_and_error_handling do
        GetDebtsResponse.new(perform(:post, 'letterdetails/get', body).body)
          .debts
          .select do |debt|
            debt['debtHistory'] = sort_by_date(debt['debtHistory'])
            debt['payeeNumber'] == '00' 
          end
      end
    end

    private

    def sort_by_date(debt_history)
      debt_history.sort_by {|d| Date::strptime(d['date'], '%m/%d/%Y')}.reverse
    end

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
