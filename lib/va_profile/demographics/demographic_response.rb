# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/demographic'

module VAProfile
  module Demographics
    class DemographicResponse < VAProfile::Response
      attribute :demographics, VAProfile::Models::Demographic

      def self.from(opts = {})
        status = opts[:status]
        body = opts[:body]
        demographic = VAProfile::Models::Demographic.build_from(body&.dig('bio'))

        demographic.id = opts[:id]
        demographic.type = opts[:type]
        demographic.gender = opts[:gender]
        demographic.birth_date = opts[:birth_date]

        new(
          status,
          demographics: demographic
        )
      end

      def gender
        demographics&.gender
      end

      def birth_date
        demographics&.birth_date
      end
    end
  end
end
