# frozen_string_literal: true

require_relative 'base'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class ServiceHistory < Base
      include VAProfile::Concerns::Defaultable

      MILITARY_SERVICE = 'Military Service'
      MILITARY_SERVICE_EPISODE = 'military_service_episodes'
      ACADEMY_ATTENDANCE = 'Academy Attendance'
      ACADEMY_ATTENDANCE_EPISODE = 'service_academy_episodes'

      attribute :service_type, String
      attribute :branch_of_service, String
      attribute :begin_date, String
      attribute :end_date, String
      attribute :termination_reason_code, String
      attribute :termination_reason_text, String
      attribute :period_of_service_type_code, String
      attribute :period_of_service_type_text, String
      attribute :branch_of_service_code, String
      attribute :deployments, Array
      attribute :character_of_discharge_code, String

      alias personnel_category_type_code period_of_service_type_code
      alias personnel_category_type_text period_of_service_type_text

      # Converts an instance of the ServicyHistory model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def self.in_json
        {
          bios: [
            {
              bioPath: 'militaryPerson.militaryServiceHistory',
              parameters: {
                scope: 'all'
              }
            }
          ]
        }.to_json
      end

      # Converts a decoded JSON response from VAProfile to an instance of the ServiceHistory model
      # @param episodes [Hash] the decoded response episodes from VAProfile
      # @return [VAProfile::Models::ServiceHistory] the model built from the response episodes
      def self.build_from(episode, episode_type)
        return nil unless episode

        return build_from_military_episode(episode) if episode_type == MILITARY_SERVICE_EPISODE

        build_from_academy_episode(episode) if episode_type == ACADEMY_ATTENDANCE_EPISODE
      end

      def self.build_from_military_episode(episode)
        VAProfile::Models::ServiceHistory.new(
          service_type: MILITARY_SERVICE,
          branch_of_service: episode['branch_of_service_text'],
          branch_of_service_code: episode['branch_of_service_code'],
          begin_date: episode['period_of_service_begin_date'],
          deployments: episode['deployments'],
          character_of_discharge_code: episode['character_of_discharge_code'],
          end_date: episode['period_of_service_end_date'],
          period_of_service_type_code: episode['period_of_service_type_code'],
          period_of_service_type_text: episode['period_of_service_type_text'],
          termination_reason_code: episode['termination_reason_code'],
          termination_reason_text: episode['termination_reason_text']
        )
      end

      def self.build_from_academy_episode(episode)
        VAProfile::Models::ServiceHistory.new(
          service_type: ACADEMY_ATTENDANCE,
          branch_of_service: episode['branch_of_service_text'],
          begin_date: episode['academy_begin_date'],
          end_date: episode['academy_end_date']
        )
      end

      def self.determine_eligibility(episodes)
        if episodes.empty?
          return { confirmed: false, message: not_found_message,
                   title: VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE,
                   status: VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS }
        end

        codes = episodes.map(&:character_of_discharge_code).uniq.compact
        # Honorable discharge
        return { confirmed: true, message: [], title: '', status: '' } if codes.intersect?(%w[A B H J])

        # Not honorable discharge
        if codes.intersect?(%w[D E F K]) || codes.empty?
          return { confirmed: false, message: not_eligible_message,
                   title: VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_TITLE,
                   status: VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_STATUS }
        end

        # No service history OR unknown (Z) discharge
        { confirmed: false, message: not_found_message,
          title: VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE,
          status: VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS }
      end

      def self.not_found_message
        if Flipper.enabled?(:vet_status_stage_1) # rubocop:disable Naming/VariableNumber
          VeteranVerification::Constants::NOT_FOUND_MESSAGE_UPDATED
        else
          VeteranVerification::Constants::NOT_FOUND_MESSAGE
        end
      end

      def self.not_eligible_message
        if Flipper.enabled?(:vet_status_stage_1) # rubocop:disable Naming/VariableNumber
          VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_UPDATED
        else
          VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE
        end
      end
    end
  end
end
