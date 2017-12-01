# frozen_string_literal: true
require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'

module EVSS
  module Letters
    class Service < EVSS::Service
      configuration EVSS::Letters::Configuration

      def get_letters
        with_monitoring do
          raw_response = perform(:get, '')
          EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
        end
      end

      def get_letter_beneficiary
        with_monitoring do
          raw_response = perform(:get, 'letterBeneficiary')
          EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
        end
      end

      def download_letter(type, options = nil)
        with_monitoring do
          headers = headers_for_user(@user)
          response = make_download_request(headers, options, type)

          case response.status.to_i
          when 200
            response.body
          when 404
            raise Common::Exceptions::RecordNotFound, type
          else
            log_message_to_sentry(
              'EVSS letter generation failed', :error, extra_context: {
                url: config.base_path, body: response.body
              }
            )
            raise_backend_exception('EVSS502', 'Letters')
          end
        end
      end

      def make_download_request(headers, options, type)
        if options.blank?
          response = download_conn.get type do |request|
            request.headers.update(headers)
          end
        else
          response = download_conn.post do |request|
            request.url "#{type}/generate"
            request.headers['Content-Type'] = 'application/json'
            request.body = options
          end
        end
        response
      end

      private

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403
          log_message_to_sentry(
            error.message, :error, extra_context: { url: config.base_path, body: error.body }
          )
          raise EVSS::Letters::ServiceException, error.body
        else
          super(error)
        end
      end

      # TODO(AJD): move to own service
      def download_conn
        @download_conn ||= Faraday.new(config.base_path, ssl: config.ssl_options) do |faraday|
          faraday.options.timeout = EVSS::Letters::Configuration::DEFAULT_TIMEOUT
          faraday.use :breakers
          faraday.use EVSS::ErrorMiddleware
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
