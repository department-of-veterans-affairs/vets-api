# frozen_string_literal: true
require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'

module EVSS
  module Letters
    class Service < EVSS::Service
      configuration EVSS::Letters::Configuration

      def get_letters(user)
        with_exception_handling do
          raw_response = perform(:get, '', nil, headers_for_user(user))
          EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
        end
      end

      def get_letter_beneficiary(user)
        with_exception_handling do
          raw_response = perform(:get, 'letterBeneficiary', nil, headers_for_user(user))
          EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
        end
      end

      def download_by_type(user, type, options = nil)
        with_exception_handling do
          headers = headers_for_user(user)
          if options.blank?
            response = download_conn.get type do |request|
              request.headers.update(headers)
            end
          else
            headers['Content-Type'] = 'application/json'
            response = download_conn.post do |request|
              request.url "#{type}/generate"
              request.headers.update(headers)
              request.body = options
            end
          end

          raise Common::Exceptions::RecordNotFound, type if response.status.to_i == 404
          response.body
        end
      end

      private

      def with_exception_handling
        yield
      rescue Faraday::ParsingError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: config.base_path })
        raise Common::Exceptions::Forbidden, detail: 'Missing correlation id'
      rescue Common::Client::Errors::ClientError => e
        raise Common::Exceptions::Forbidden if e.status == 403
        log_message_to_sentry(
          e.message, :error, extra_context: { url: config.base_path, body: e.body }
        )
        raise EVSS::Letters::ServiceException, e.body
      end

      # TODO(AJD): move to own service
      def download_conn
        @download_conn ||= Faraday.new(config.base_path, ssl: config.ssl_options) do |faraday|
          faraday.options.timeout = 15
          faraday.use :breakers
          faraday.adapter :httpclient
        end
      end
    end
  end
end
