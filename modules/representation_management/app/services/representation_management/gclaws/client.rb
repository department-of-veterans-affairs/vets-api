# frozen_string_literal: true

# This client is responsible for retrieving accreditation data from the GCLAWS API.

module RepresentationManagement
  module GCLAWS
    class Client
      ALLOWED_TYPES = %w[agents attorneys representatives veteran_service_organizations].freeze
      DEFAULT_PAGE = 1
      DEFAULT_PAGE_SIZE = 100

      def self.get_accredited_entities(type:, page: DEFAULT_PAGE, page_size: DEFAULT_PAGE_SIZE)
        return {} unless ALLOWED_TYPES.include?(type)

        configuration = GCLAWS::Configuration.new(type:, page:, page_size:)

        configuration.connection.get
      rescue Faraday::ConnectionFailed
        Rails.logger.error(
          "GCLAWS Accreditation connection failed for #{type}"
        )
        Faraday::Response.new(status: :service_unavailable,
                              body: { errors: 'GCLAWS Accreditation unavailable' }.to_json)
      rescue Faraday::TimeoutError
        Rails.logger.error("GCLAWS Accreditation request timed out for #{type}")
        Faraday::Response.new(status: :request_timeout,
                              body: { errors: 'GCLAWS Accreditation request timed out' }.to_json)
      end
    end
  end
end
