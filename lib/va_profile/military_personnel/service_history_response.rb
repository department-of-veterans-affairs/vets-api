# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/service_history'

module VAProfile
  module MilitaryPersonnel
    class ServiceHistoryResponse < VAProfile::Response
      attribute :episodes, Array
      attribute :uniformed_service_initial_entry_date, String
      attribute :release_from_active_duty_date, String
      attribute :vet_status_eligibility, Object

      def self.from(current_user, raw_response = nil)
        body = raw_response&.body

        episodes = []
        episodes += get_military_service_episodes(body)
        episodes += get_academy_attendance_episodes(body) if include_academy_attendance?(current_user)

        new(
          raw_response&.status,
          episodes: episodes ? sort_by_begin_date(episodes) : episodes,
          uniformed_service_initial_entry_date: get_uniformed_service_initial_entry_date(body),
          release_from_active_duty_date: get_release_from_active_duty_date(body),
          vet_status_eligibility: get_eligibility(episodes)
        )
      end

      def self.get_military_service_episodes(body)
        get_episodes(body, VAProfile::Models::ServiceHistory::MILITARY_SERVICE_EPISODE) || []
      end

      def self.get_academy_attendance_episodes(body)
        get_episodes(body, VAProfile::Models::ServiceHistory::ACADEMY_ATTENDANCE_EPISODE) || []
      end

      def self.get_episodes(body, episode_type)
        return nil unless body && episode_type

        episodes = body&.dig(
          'profile',
          'military_person',
          'military_service_history',
          episode_type)

        episodes&.map { |e| VAProfile::Models::ServiceHistory.build_from(e, episode_type) }
      end

      def self.get_uniformed_service_initial_entry_date(body)
        body&.dig(
          'profile',
          'military_person',
          'military_service_history',
          'uniformed_service_initial_entry_date')
      end

      def self.get_release_from_active_duty_date(body)
        body&.dig(
          'profile',
          'military_person',
          'military_service_history',
          'release_from_active_duty_date')
      end

      def self.sort_by_begin_date(service_episodes)
        service_episodes.sort_by { |se| se.begin_date || Time.zone.today + 3650 }
      end

      def self.include_academy_attendance?(current_user)
        Flipper.enabled?(:profile_show_military_academy_attendance, current_user)
      end

      def self.get_eligibility(episodes)
        VAProfile::Models::ServiceHistory.determine_eligibility(episodes)
      end
    end
  end
end
