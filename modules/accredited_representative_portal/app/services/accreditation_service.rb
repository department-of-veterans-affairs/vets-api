# frozen_string_literal: true

# AccreditationService is responsible for handling the submission of Form 21a to the accreditation service.
# It provides a single class method `submit_form21a` to send the form data and handle the response.
# The service URL is determined based on the current environment (development, test, production).

class AccreditationService
  # self.submit_form21a(parsed_body): Submits the given parsed body as JSON to the accreditation service.
  #   - Parameters:
  #     - parsed_body: A Hash representing the parsed form data.
  #     - user_uuid: A String representing the user's UUID, which is also stored in the in_progress_forms DB entry.
  #   - Returns: A Faraday::Response object containing the service response.
  def self.submit_form21a(parsed_body, user_uuid)
    Rails.logger.info("Accreditation Service attempting submit_form21a with service_url: #{service_url}")
    connection.post do |req|
      req.headers['x-api-key'] = Settings.ogc.form21a_service_url.api_key
      req.body = parsed_body.to_json
    end
  rescue Faraday::ConnectionFailed => e
    Rails.logger.error(
      "Accreditation Service connection failed for user with user_uuid=#{user_uuid}: #{e.message}, URL: #{service_url}"
    )
    Faraday::Response.new(status: :service_unavailable, body: { errors: 'Accreditation Service unavailable' }.to_json)
  rescue Faraday::TimeoutError => e
    Rails.logger.error("Accreditation Service request timed out for user with user_uuid=#{user_uuid}: #{e.message}")
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
    Settings.ogc.form21a_service_url.url
  end
end
