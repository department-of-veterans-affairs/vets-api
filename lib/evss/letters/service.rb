# frozen_string_literal: true
require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'

module EVSS
  module Letters
    class Service < EVSS::Service
      configuration EVSS::Letters::Configuration

      STATSD_KEYS = {
        get_letters_total: 'api.evss.get_letters.total',
        get_letters_fail: 'api.evss.get_letters.fail',
        get_letter_beneficiary_total: 'api.evss.get_letter_beneficiary.total',
        get_letter_beneficiary_fail: 'api.evss.get_letter_beneficiary.fail',
        download_by_type_total: 'api.evss.download_letter.total',
        download_by_type_fail: 'api.evss.download_letter.fail'
      }.freeze

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
          headers['Content-Type'] = 'application/json'
          response = download_conn.post do |request|
            request.url "#{type}/generate"
            request.headers.update(headers)
            request.body = options
          end
        end
        response
      end

      private

      def with_exception_handling
        caller = caller_locations(1, 1)[0].label
        yield
      rescue StandardError => error
        StatsD.increment(STATSD_KEYS["#{caller}_fail".to_sym], tags: ["error:#{error.class}"])
        handle_error(error)
      ensure
        StatsD.increment(STATSD_KEYS["#{caller}_total".to_sym])
      end

      def handle_error(error)
        case error
        when Faraday::ParsingError
          log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path })
          raise Common::Exceptions::Forbidden, detail: 'Missing correlation id'
        when Common::Client::Errors::ClientError
          raise Common::Exceptions::Forbidden if error.status == 403
          log_message_to_sentry(
            error.message, :error, extra_context: { url: config.base_path, body: error.body }
          )
          raise EVSS::Letters::ServiceException, error.body
        else
          raise error
        end
      end

      # TODO(AJD): move to own service
      def download_conn
        @download_conn ||= Faraday.new(config.base_path, ssl: config.ssl_options) do |faraday|
          faraday.options.timeout = 15
          faraday.use :breakers
          faraday.use EVSS::ErrorMiddleware
          faraday.use(Common::Client::Middleware::Request::RemoveCookies)
          faraday.adapter :httpclient
        end
      end
    end
  end
end
