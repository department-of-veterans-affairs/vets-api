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

  # NOTE: The interface between GCLAWS/OGC and vets-api is not yet established due to ongoing ESECC and MOU requests.
  # TODO: Update the service URL based on the actual production and QA URLs once the below issue is resolved. See:
  # https://github.com/department-of-veterans-affairs/va.gov-team/issues/85933
  # https://dsva.slack.com/archives/C06ABHUNBRS/p1721769692072489
  # self.service_url: Determines and returns the service URL based on the current environment.
  def self.service_url
    case Rails.env
    when 'development', 'test'
      # NOTE: the below is a temporary URL for development purposes only.
      # TODO: Update this once ESECC request goes through. See: https://github.com/department-of-veterans-affairs/va.gov-team/issues/88288
      'http://localhost:5000/api/v1/accreditation/applications/form21a'
    when 'production'
      # TODO: Update this once MOU has been signed and the ESECC request has gone through. See:
      # https://dsva.slack.com/archives/C06ABHUNBRS/p1721769692072489
      # https://github.com/department-of-veterans-affairs/va.gov-team/issues/85933
      raise 'Accreditation service URL not configured for production'
    end
  end
end
