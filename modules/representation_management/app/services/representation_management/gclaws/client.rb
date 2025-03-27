# frozen_string_literal: true

# This client is responsible for retrieving accreditation data from the GCLAWS API.

module RepresentationManagement
  module GCLAWS
    class Client
      DEFAULT_PAGE = 1
      DEFAULT_PAGE_SIZE = 100
      def get_agents(page: DEFAULT_PAGE, page_size: DEFAULT_PAGE_SIZE)
        configuration = GCLAWS::Configuration.new(type: 'agents', page:, page_size:)

        configuration.connection.get
      end

      # self.submit_form21a(parsed_body): Submits the given parsed body as JSON to the gclaws service.
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
        Faraday::Response.new(status: :service_unavailable,
                              body: { errors: 'Accreditation Service unavailable' }.to_json)
      rescue Faraday::TimeoutError => e
        Rails.logger.error("Accreditation Service request timed out for user with user_uuid=#{user_uuid}: #{e.message}")
        Faraday::Response.new(status: :request_timeout,
                              body: { errors: 'Accreditation Service request timed out' }.to_json)
      end
    end
  end
end
