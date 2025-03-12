# frozen_string_literal: true

module ClaimsApi
  module EndpointDeprecation
    extend ActiveSupport::Concern

    V1_DEV_DOCS = 'https://developer.va.gov/explore/benefits/docs/claims?version=1.0.0'

    included do
      def add_deprecation_headers_to_response(response:, link: nil)
        response.headers['Deprecation'] = 'true'
        response.headers['Link'] = link if link.present?
      end
    end
  end
end
