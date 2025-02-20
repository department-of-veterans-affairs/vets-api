# frozen_string_literal: true

module AppealsApi
  module HeaderModification
    extend ActiveSupport::Concern

    V1_DEV_DOCS = 'https://developer.va.gov/explore/appeals/docs/decision_reviews?version=1.0.0'
    V2_DEV_DOCS = 'https://developer.va.gov/explore/appeals/docs/decision_reviews?version=2.0.0'
    RELEASE_NOTES_LINK = 'https://developer.va.gov/release-notes/appeals'

    included do
      def deprecate(response:, link: nil, sunset: nil)
        response.headers['Deprecation'] = 'true'
        response.headers['Link'] = link if link.present?
        response.headers['Sunset'] = sunset if sunset.present?
      end
    end
  end
end
