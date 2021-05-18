# frozen_string_literal: true

module AppealsApi
  module HeaderModification
    extend ActiveSupport::Concern

    included do
      V1_DEV_DOCS = 'https://developer.va.gov/explore/appeals/docs/decision_reviews?version=1.0.0'
      V2_DEV_DOCS = 'https://developer.va.gov/explore/appeals/docs/decision_reviews?version=2.0.0'

      def deprecate(response:, link: nil)
        response.headers['Deprecation'] = 'true'
        response.headers['Link'] = link if link.present?
      end
    end
  end
end
