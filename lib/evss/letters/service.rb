# frozen_string_literal: true
require 'evss/base_service'
require 'common/exceptions/internal/record_not_found'

module EVSS
  module Letters
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-lettergenerator-services-web/rest/letters/v1"

      def initialize(headers)
        super(headers)
      end

      def get_letters
        raw_response = get ''
        EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: BASE_URL })
        EVSS::Letters::LettersResponse.new(403)
      rescue Faraday::ClientError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: BASE_URL })
        EVSS::Letters::LettersResponse.new(e.response[:status])
      end

      def get_letter_beneficiary
        raw_response = get 'letterBeneficiary'
        EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
      rescue Faraday::ParsingError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: BASE_URL })
        EVSS::Letters::BeneficiaryResponse.new(403)
      rescue Faraday::ClientError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: BASE_URL })
        EVSS::Letters::BeneficiaryResponse.new(e.response[:status])
      end

      def download_letter_by_type(type)
        response = download_conn.get type
        raise Common::Exceptions::RecordNotFound, params[:id] if response.status.to_i == 404
        response.body
      end

      def self.breakers_service
        BaseService.create_breakers_service(name: 'EVSS/Letters', url: BASE_URL)
      end

      private

      def download_conn
        @download_conn ||= Faraday.new(base_url, headers: @headers, ssl: ssl_options) do |faraday|
          faraday.options.timeout = timeout
          faraday.use      :breakers
          faraday.adapter  :httpclient
        end
      end
    end
  end
end
