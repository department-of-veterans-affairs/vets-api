# frozen_string_literal: true
require 'evss/base_service'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'

module EVSS
  module Letters
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-lettergenerator-services-web/rest/letters/v1"

      def initialize(headers)
        super(headers)
      end

      def get_letters
        with_exception_handling do
          raw_response = get ''
          EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
        end
      end

      def get_letter_beneficiary
        with_exception_handling do
          raw_response = get 'letterBeneficiary'
          EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
        end
      end

      def download_by_type(type, options = nil)
        with_exception_handling do
          if options.blank?
            response = download_conn.get type
          else
            response = download_conn.post do |req|
              req.url "#{type}/generate"
              req.headers['Content-Type'] = 'application/json'
              req.body = options
            end
          end

          raise Common::Exceptions::RecordNotFound, type if response.status.to_i == 404
          response.body
        end
      end

      def self.breakers_service
        BaseService.create_breakers_service(name: 'EVSS/Letters', url: BASE_URL)
      end

      private

      def with_exception_handling
        yield
      rescue Faraday::ParsingError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: BASE_URL })
        raise Common::Exceptions::Forbidden, detail: 'Missing correlation id'
      rescue Faraday::TimeoutError
        log_message_to_sentry(
          'Timeout while connecting to Letters service', :error, extra_context: { url: BASE_URL }
        )
        raise Common::Exceptions::GatewayTimeout
      rescue Faraday::ClientError => e
        raise Common::Exceptions::Forbidden if e.response[:status] == 403
        log_message_to_sentry(
          e.message, :error, extra_context: { url: BASE_URL, body: e.response[:body] }
        )
        raise EVSS::Letters::ServiceException, e.response[:body]
      end

      def download_conn
        @download_conn ||= Faraday.new(base_url, headers: @headers, ssl: ssl_options) do |faraday|
          faraday.options.timeout = timeout
          faraday.use :breakers
          faraday.adapter :httpclient
        end
      end
    end
  end
end
