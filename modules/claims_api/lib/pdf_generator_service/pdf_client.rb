# frozen_string_literal: true

require 'common/file_helpers'

module ClaimsApi
  ##
  # Class to interact with the pdf generator service

  class PDFClient
    def initialize(request_body = nil)
      @request_body = request_body
    end

    def generate_pdf
      url = Settings.claims_api.pdf_generator_526.url
      path = Settings.claims_api.pdf_generator_526.path
      content_type = Settings.claims_api.pdf_generator_526.content_type
      conn = Faraday.new("#{url}#{path}",
                         ssl: { verify: false },
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
      conn.post('526', @request_body).body
    end
  end
end
