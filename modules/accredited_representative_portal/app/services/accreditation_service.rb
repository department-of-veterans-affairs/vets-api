# frozen_string_literal: true

# AccreditationService is responsible for handling the submission of Form 21a to the accreditation service.
# It provides a single class method `submit_form21a` to send the form data and handle the response.
# The service URL is determined based on the current environment (development, test, production).

class AccreditationService
  SERVICE_NAME = 'accredited-representative-portal'

  # self.submit_form21a(parsed_body): Submits the given parsed body as JSON to the accreditation service.
  #   - Parameters:
  #     - parsed_body: A Hash representing the parsed form data.
  #     - user_uuid: A String representing the user's UUID, which is also stored in the in_progress_forms DB entry.
  #   - Returns: A Faraday::Response object containing the service response.
  # rubocop:disable Metrics/MethodLength
  def self.submit_form21a(parsed_body, user_uuid)
    monitor = AccreditedRepresentativePortal::MonitoringService.new(SERVICE_NAME)

    monitor.track_event(
      :info,
      'Submitting Form 21a',
      'api.arp.form21a.submit',
      ["user_uuid:#{user_uuid}"]
    )

    response = connection.post do |req|
      req.headers['x-api-key'] = Settings.ogc.form21a_service_url.api_key
      req.body = parsed_body.to_json
    end

    monitor.track_event(
      :info,
      'Form 21a Submission Success',
      'api.arp.form21a.success',
      ["user_uuid:#{user_uuid}"]
    )

    response
  rescue Faraday::ConnectionFailed => e
    monitor.track_error(
      'Accreditation Service Connection Failed',
      'api.arp.form21a.connection_failed',
      e.class.name,
      ["user_uuid:#{user_uuid}",
       "error:#{e.message}"]
    )

    Faraday::Response.new(status: :service_unavailable, body: { errors: 'Accreditation Service unavailable' }.to_json)
  rescue Faraday::TimeoutError => e
    monitor.track_error(
      'Accreditation Service Timeout',
      'api.arp.form21a.timeout',
      e.class.name,
      ["user_uuid:#{user_uuid}",
       "error:#{e.message}"]
    )

    Faraday::Response.new(status: :request_timeout, body: { errors: 'Accreditation Service request timed out' }.to_json)
  end
  # rubocop:enable Metrics/MethodLength

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
