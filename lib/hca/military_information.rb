# frozen_string_literal: true

require 'va_profile/military_personnel/service'

module HCA
  class MilitaryInformation
    PREFILL_METHODS = %w[
      hca_last_service_branch
      last_entry_date
      last_discharge_date
      discharge_type
      post_nov111998_combat
      sw_asia_combat
    ].freeze

    HCA_SERVICE_BRANCHES = {
      'A' => 'army',
      'C' => 'coast guard',
      'F' => 'air force',
      'H' => 'usphs',
      'M' => 'marine corps',
      'N' => 'navy',
      'O' => 'noaa'
    }.freeze

    DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'F' => 'dishonorable',
      'J' => 'honorable',
      'K' => 'dishonorable'
    }.freeze

    SOUTHWEST_ASIA = %w[
      AM
      AZ
      BH
      CY
      GE
      IQ
      IL
      JO
      KW
      LB
      OM
      QA
      SA
      SY
      TR
      AE
      YE
    ].freeze

    NOV_1998 = Date.new(1998, 11, 11)
    GULF_WAR_RANGE = (Date.new(1990, 8, 2)..NOV_1998)

    def initialize(user)
      @service = VAProfile::MilitaryPersonnel::Service.new(user)
    end

    def service_episodes_by_date
      @service_episodes_by_date ||= military_service_episodes.sort_by do |ep|
        if ep.end_date.blank?
          Time.zone.today + 3650
        else
          Date.parse(ep.end_date)
        end
      end.reverse
    end

    def hca_last_service_branch
      HCA_SERVICE_BRANCHES[latest_service_episode&.branch_of_service_code] || 'other'
    end

    def latest_service_episode
      service_episodes_by_date.try(:[], 0)
    end

    def military_service_episodes
      service_history.episodes.find_all do |episode|
        episode.service_type == 'Military Service'
      end
    end

    def sw_asia_combat
      deployed_to?(SOUTHWEST_ASIA, GULF_WAR_RANGE)
    end

    def deployed_to?(countries, date_range)
      deployments.each do |deployment|
        deployment['deployment_locations'].each do |location|
          location_date_range = location['deployment_location_begin_date']..location['deployment_location_end_date']

          if countries.include?(location['deployment_country_code']) && date_range.overlaps?(location_date_range)
            return true
          end
        end
      end

      false
    end

    def post_nov111998_combat
      deployments.each do |deployment|
        return true if Date.parse(deployment['deployment_end_date']) > NOV_1998
      end

      false
    end

    def discharge_type
      return if latest_service_episode.blank?

      DISCHARGE_TYPES[latest_service_episode&.character_of_discharge_code]
    end

    def last_discharge_date
      latest_service_episode&.end_date
    end

    def last_entry_date
      latest_service_episode&.begin_date
    end

    def deployments
      @deployments ||= lambda do
        return_val = []

        service_history.episodes.each do |episode|
          return_val += episode.deployments if episode.deployments.present?
        end

        return_val
      end.call
    end

    private

    def service_history
      @service_history ||= @service.get_service_history
    end
  end
end
