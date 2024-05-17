# frozen_string_literal: true

require 'common/file_helpers'
require 'claims_api/claim_logger'
require 'common/client/errors'
require 'custom_error'

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

      error_handler(e)
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
        f.response :raise_error
        f.response :logger,
                   Rails.logger,
                   headers: true,
                   bodies: false,
                   log_level: :debug
        f.adapter Faraday.default_adapter
      end
    end

    def log_outcome_for_claims_api(action, status, response)
      ClaimsApi::Logger.log('526_docker_container',
                            detail: "EVSS DOCKER CONTAINER #{action} #{status},  is a string: #{response}")
    end

    def custom_error(error)
      ClaimsApi::CustomError.new(error)
    end

    def error_handler(error)
      custom_error(error).build_error
    end
  end
end
