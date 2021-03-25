# frozen_string_literal: true

module ClaimsApi
  module EndpointDeprecation
    extend ActiveSupport::Concern

    included do
      def add_deprecation_headers_to_response(response:, link: nil)
        response.headers['Deprecation'] = 'true'
        response.headers['Link'] = link if link.present?
      end
    end
  end
end
