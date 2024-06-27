# frozen_string_literal: true

# AccreditationService is responsible for handling the submission of Form 21a to the accreditation service.
# It provides a single class method `submit_form21a` to send the form data and handle the response.
# The service URL is determined based on the current environment (development, test, production).

class AccreditationService
  # self.submit_form21a(parsed_body): Submits the given parsed body as JSON to the accreditation service.
  #   - Parameters:
  #     - parsed_body: A Hash representing the parsed form data.
  #   - Returns: A Faraday::Response object containing the service response.
  def self.submit_form21a(parsed_body)
    connection.post do |req|
      req.body = parsed_body.to_json
    end
  rescue Faraday::ConnectionFailed => e
    Rails.logger.error("Accreditation Service connection failed: #{e.message}, URL: #{service_url}")
    Faraday::Response.new(status: :service_unavailable, body: { errors: 'Accreditation Service unavailable' }.to_json)
  rescue Faraday::TimeoutError => e
    Rails.logger.error("Accreditation Service request timed out: #{e.message}")
    Faraday::Response.new(status: :request_timeout, body: { errors: 'Accreditation Service request timed out' }.to_json)
  end

  # self.connection: Creates and returns a Faraday connection configured with JSON request and response handling.
  def self.connection
    Faraday.new(url: service_url) do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
    end
  end

  # self.service_url: Determines and returns the service URL based on the current environment.
  def self.service_url
    # TODO: Update the service URL based on the actual production and QA URLs once available.
    # See ZH 85933: https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/85933
    case Rails.env
    when 'development', 'test'
      'http://localhost:5000/api/v1/accreditation/applications/form21a' # TODO: Update with OGC URLs
      # See ZH: https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/87177
    when 'production'
      # TODO: Update with actual OGC production URL
      # See ZH: https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/87177
    end
  end
end
