# frozen_string_literal: true

require 'common/file_helpers'
require 'claims_api/claim_logger'
require 'claims_api/common/exceptions/lighthouse/bad_request'

module ClaimsApi
  ##
  # Class to interact with the pdf generator service

  class PDFClient
    def initialize(request_body = nil)
      @request_body = request_body
    end

    def generate_pdf
      resp = client.post('526', @request_body).body
      log_outcome_for_claims_api('pdf_generator', 'success', resp.is_a?(String))

      resp
    rescue => e
      detail = e.respond_to?(:original_body) ? e.original_body : e
      log_outcome_for_claims_api('pdf_generator', 'error', detail)

      raise ::ClaimsApi::Common::Exceptions::Lighthouse::BadRequest,
            JSON.parse(detail).deep_symbolize_keys[:errors]
    end

    private

    def client
      url = Settings.claims_api.pdf_generator_526.url
      path = Settings.claims_api.pdf_generator_526.path
      content_type = Settings.claims_api.pdf_generator_526.content_type
      Faraday.new("#{url}#{path}",
                  ssl: { verify: !Rails.env.development? },
                  headers: { 'Content-Type': content_type.to_s }) do |f|
        f.request :json
        f.response :raise_custom_error
        f.response :logger,
                   Rails.logger,
                   headers: true,
                   bodies: false,
                   log_level: :debug
        f.adapter Faraday.default_adapter
      end
    end

    def log_outcome_for_claims_api(action, status, response)
      ClaimsApi::Logger.log('526_pdf_client',
                            detail: "PDF Client #{action} #{status},  is a string: #{response}")
    end
  end
end
