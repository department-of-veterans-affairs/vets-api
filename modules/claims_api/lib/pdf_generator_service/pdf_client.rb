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
      url = Settings.pdf_generator.url
      path = Settings.pdf_generator.path
      content_type = Settings.pdf_generator.content_type
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
      response = conn.post('526', @request_body).body
      ::Common::FileHelpers.generate_temp_file(response, "#{SecureRandom.hex}.pdf")
    end
  end
end
