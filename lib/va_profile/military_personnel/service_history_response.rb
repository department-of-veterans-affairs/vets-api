# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/service_history'

module VAProfile
  module MilitaryPersonnel
    class ServiceHistoryResponse < VAProfile::Response
      attribute :episodes, Array

      def branch_of_service
        episodes&.branch_of_service
      end

      def begin_date
        episodes&.begin_date
      end

      def end_date
        episodes&.end_date
      end

      def personnel_category_type_code
        episodes&.personnel_category_type_code
      end

      def self.from(raw_response = nil)
        response_body = raw_response&.body
        service_episodes = response_body&.dig(
          'profile',
          'military_person',
          'military_service_history',
          'military_service_episodes')

        new(
          raw_response&.status,
          episodes: service_episodes&.map { |e| VAProfile::Models::ServiceHistory.build_from(e) }
        )
      end
    end
  end
end
