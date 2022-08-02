# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/service_history'

module VAProfile
  module MilitaryPersonnel
    class ServiceHistoryResponse < VAProfile::Response
      attribute :episodes, Array

      def self.from(raw_response = nil)
        response_body = raw_response&.body
        service_episodes = response_body&.dig(
          'profile',
          'military_person',
          'military_service_history',
          'military_service_episodes')

        episodes = service_episodes&.map { |e| VAProfile::Models::ServiceHistory.build_from(e) }

        new(
          raw_response&.status,
          episodes: episodes ? sort_by_begin_date(episodes) : episodes
        )
      end

      def self.sort_by_begin_date(service_episodes)
        service_episodes.sort_by { |se| se.begin_date || Time.zone.today + 3650 }
      end
    end
  end
end
